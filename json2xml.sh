#!/bin/bash
#
###############################################################################
# Script name:    json2xml.sh
# Description:    Parses a JSON file into XML data
# Author:         Brian Geis
# GitHub:         https://github.com/briangeis/json2xml
# Copyright:      GNU General Public License v3.0
###############################################################################
#
#
#
#
###############################################################################
# Show the help documentation
###############################################################################
show_help() {

    printf "Parses a JSON file into XML data.\n"
    printf "\nUsage: %s [options] json_file [xml_file]\n" "$0"
    printf "\nOptions:\n"
    printf "  -h      Show the help documentation\n"
    printf "  -a      Append XML data to output file\n"
    printf "  -i N    Set the indentation to N spaces (default: 4)\n"
    printf "  -t      Use tab indentation instead of spaces\n"
    printf "  -x      Omit the header from the XML data\n"
    printf "\nExamples:\n"
    printf "  ./json2xml.sh -i 2 sample1.json\n"
    printf "  ./json2xml.sh -t sample2.json output.xml\n"
    printf "  ./json2xml.sh -atx sample3.json output.xml\n"
    printf "\nFull documentation available at:\n"
    printf " https://github.com/briangeis/json2xml\n"

}

###############################################################################
# Exit traps
###############################################################################
exit_trap() {

    case "$?" in
    1)
        printf "Try '%s -h' for more information.\n" "$0" >&2
        ;;
    20)
        # object is missing a ',' or '}'
        printf "%s: error in input file: ',' or '}' expected!" "$0" >&2
        printf " (Line %s:%s)\n" "${line_count}" "${pos_count-1}" >&2
        ;;
    21)
        # array is missing a ',' or ']'
        printf "%s: error in input file: ',' or ']' expected!" "$0" >&2
        printf " (Line %s:%s)\n" "${line_count}" "${pos_count-1}" >&2
        ;;
    22)
        # property (name/value pair) is missing a separating ':'
        printf "%s: error in input file: ':' expected!" "$0" >&2
        printf " (Line %s:%s)\n" "${line_count}" "${pos_count-1}" >&2
        ;;
    23)
        # string is missing ending quotation mark
        printf "%s: error in input file: '\"' expected!" "$0" >&2
        printf " (Line %s:%s)\n" "${line_count}" "${pos_count-1}" >&2
        ;;
    24)
        # an invalid value was found
        pos_count=$((pos_count - "${#value}"))
        printf "%s: error in input file: invalid value!" "$0" >&2
        printf " (Line %s:%s)\n" "${line_count}" "${pos_count}" >&2
        ;;
    25)
        # unexpected end of input file
        printf "%s: error: unexpected end of input file!\n" "$0" >&2
        ;;
    esac

}

###############################################################################
# Increment the input file index and column positions
# Arguments:
#   $1 Optional exit code to use if end of input is reached unexpectedly
###############################################################################
increment_index() {

    # check for unexpected end of input file
    if ((index >= "${#input}")); then
        if (($# == 1)); then
            exit "$1"
        else
            exit 25
        fi
    fi
    # increment line count and reset position count on newline
    if [[ "${input:$index:1}" == $'\n' ]]; then
        ((line_count++))
        pos_count=1
    else
        ((pos_count++))
    fi
    # increment the index
    ((index++))

}

###############################################################################
# Skip whitespace characters and update index position
###############################################################################
skip_whitespace() {

    while [[ "${input:$index:1}" =~ [[:space:]] ]]; do
        increment_index
    done

}

###############################################################################
# Update the indentation string for XML output
###############################################################################
update_indentation() {

    indentation=''
    local i
    if ((use_tab_indents)); then
        for ((i = 0; i < nested_level; i++)); do
            indentation+="\t"
        done
    else
        for ((i = 0; i < (indent_spaces * nested_level); i++)); do
            indentation+=' '
        done
    fi

}

###############################################################################
# Generate an XML start tag for the output
# Arguments:
#   $1 The tag name for the element
#   $2 A optional flag to indicate this is a tag for an object value
###############################################################################
output_xml_start_tag() {

    if (($# == 1)); then
        output+="${indentation}<$1>"
    else
        output+="${indentation}<$1>\n"
        ((nested_level++))
        update_indentation
    fi

}

###############################################################################
# Generate an XML end tag for the output
# Arguments:
#   $1 The tag name for the element
#   $2 An optional flag to indicate this is a tag for an object value
###############################################################################
output_xml_end_tag() {

    if (($# == 1)); then
        output+="</$1>\n"
    else
        ((nested_level--))
        update_indentation
        output+="${indentation}</$1>\n"
    fi

}

###############################################################################
# Process a property (name/value pair)
###############################################################################
process_property() {

    # the name of the property
    local name=''

    # first expected character is a '"'
    skip_whitespace
    if [[ "${input:$index:1}" != '"' ]]; then
        exit 23
    fi
    # increment index past the '"'
    increment_index
    # check if the first character of the name is valid XML
    # if it is not, add a '_' to the start of the name
    if ! [[ "${input:$index:1}" =~ [A-Za-z:_] ]]; then
        name+='_'
    fi
    # process characters until the end of name string is reached
    #   note 1: spaces are replaced with underscores
    #   note 2: invalid XML name characters are skipped
    local end_of_name=0
    while ! ((end_of_name)); do
        if [[ "${input:$index:1}" == '"' ]]; then
            end_of_name=1
        elif [[ "${input:$index:1}" == ' ' ]]; then
            name+='_'
        elif [[ "${input:$index:1}" =~ [A-Za-z0-9:_.-] ]]; then
            name+="${input:$index:1}"
        fi
        # trigger exit code 23 if string is improperly terminated
        increment_index 23
    done
    # if the name value contains no valid XML characters
    # then use the generic name of 'element'
    if [[ "${name}" == '_' ]]; then
        name='element'
    fi
    # next expected character is a ':' separator
    skip_whitespace
    if [[ "${input:$index:1}" != ':' ]]; then
        exit 22
    fi
    # increment index past the ':' and process the value
    increment_index
    process_value

}

###############################################################################
# Process a property value
# Arguments:
#   $1 An optional flag to indicate this is the root value
###############################################################################
process_value() {

    # the value of the property
    local value=''

    # expected input is a value. possible types are:
    # object, array, string, number, 'true', 'false', 'null'
    skip_whitespace
    if [[ "${input:$index:1}" == '{' ]]; then
        # value is an object
        if ! (($#)); then
            output_xml_start_tag "${name}" 1
        fi
        process_object
        if ! (($#)); then
            output_xml_end_tag "${name}" 1
        fi
    elif [[ "${input:$index:1}" == '[' ]]; then
        # value is an array
        if (($#)); then
            output_xml_start_tag 'array' 1
            local name='element'
        fi
        process_array
        if (($#)); then
            output_xml_end_tag 'array' 1
        fi
    elif [[ "${input:$index:1}" == '"' ]]; then
        # value is a string
        if (($#)); then
            local name='element'
        fi
        output_xml_start_tag "${name}"
        process_string
        output+="${value}"
        output_xml_end_tag "${name}"
    else
        # value is a number, 'true', 'false', or 'null'
        if (($#)); then
            local name='element'
        fi
        output_xml_start_tag "${name}"
        process_other
        output+="${value}"
        output_xml_end_tag "${name}"
    fi

}

###############################################################################
# Process an object property value
###############################################################################
process_object() {

    # increment index past the '{'
    increment_index
    # iterate through all properties (name/value pairs) in object
    local end_of_object=0
    while ! ((end_of_object)); do
        # next expected input is a property
        process_property
        # next expected value is either:
        #   a ',' to separate name/value pairs
        #   a '}' to indicate the end of the object
        skip_whitespace
        if [[ "${input:$index:1}" == '}' ]]; then
            end_of_object=1
        elif ! [[ "${input:$index:1}" == ',' ]]; then
            exit 20
        fi
        # increment index past the ',' or '}'
        increment_index
    done

}

###############################################################################
# Process an array property value
###############################################################################
process_array() {

    # increment index past the '['
    increment_index
    # iterate through all values in the array
    local end_of_array=0
    while ! ((end_of_array)); do
        # next expected input is a value
        process_value
        # next expected value is either:
        #   a ',' to separate values
        #   a ']' to indicate the end of the array
        skip_whitespace
        if [[ "${input:$index:1}" == ']' ]]; then
            end_of_array=1
        elif ! [[ "${input:$index:1}" == ',' ]]; then
            exit 21
        fi
        # increment index past the ',' or ']'
        increment_index
    done

}

###############################################################################
# Process a string property value
###############################################################################
process_string() {

    # increment index past the '"'
    increment_index
    # process characters until the end of string is reached
    local end_of_string=0
    while ! ((end_of_string)); do
        if [[ "${input:$index:1}" == '"' ]]; then
            end_of_string=1
        elif [[ "${input:$index:1}" == "\\" ]]; then
            # handle JSON control characters with valid XML equivalnets
            case "${input:$index+1:1}" in
            't')
                value+='&#x09;'
                ;;
            'n')
                value+='&#x0A;'
                ;;
            'r')
                value+='&#x0D;'
                ;;
            '"')
                value+='&quot;'
                ;;
            "\\")
                value+="\\\\"
                ;;
            '/')
                value+='/'
                ;;
            esac
            # allow normal processing of escaped unicode characters
            if [[ "${input:$index+1:1}" == 'u' ]]; then
                value+="\\"
            else
                increment_index
            fi
        else
            # insert XML character references for reserved characters
            case "${input:$index:1}" in
            '<')
                value+='&lt;'
                ;;
            '>')
                value+='&gt;'
                ;;
            '&')
                value+='&amp;'
                ;;
            "'")
                value+='&apos;'
                ;;
            *)
                value+="${input:$index:1}"
                ;;
            esac
        fi
        # trigger exit code 23 if string is improperly terminated
        increment_index 23
    done

}

###############################################################################
# Process an number, 'true', 'false', or 'null'  property value
###############################################################################
process_other() {

    # process characters until the end of the value is reached
    while [[ "${input:$index:1}" =~ [truefalsn0-9E.+-] ]]; do
        value+="${input:$index:1}"
        increment_index
    done
    # ensure value is a valid number, 'true', 'false', or 'null'
    if ! [[ "${value}" =~ ^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$ ||
        "${value}" == 'true' ||
        "${value}" == 'false' ||
        "${value}" == 'null' ]]; then
        exit 24
    fi

}

###############################################################################
# Main program
###############################################################################
main() {

    trap exit_trap EXIT

    # input JSON file contents
    local input=''
    # output XML data
    local output='<?xml version="1.0" encoding="UTF-8"?>\n'
    # index of current character in input file
    local index=0
    # current line of index in input file
    local line_count=1
    # current position of index in input file
    local pos_count=1
    # current nested level (for XML indentation)
    local nested_level=0
    # number of spaces to indent in output per nested level
    local indent_spaces=4
    # indentation string used for output
    local indentation=''
    # flag to determine if output should be appended to target file
    local append_output=0
    # flag to determine if tab indentation should be used
    local use_tab_indents=0

    # process the options
    while getopts ":hai:tx" option; do
        case "${option}" in
        h)
            # show the help
            show_help
            exit 0
            ;;
        a)
            # append output to target file
            append_output=1
            ;;
        i)
            # specify the indentation level
            if [[ "${OPTARG}" =~ ^[0-9]*$ ]]; then
                indent_spaces="${OPTARG}"
            else
                printf "%s: invalid indentation size: " "$0" >&2
                printf "'%s'\n" "${OPTARG}" >&2
                exit 1
            fi
            ;;
        t)
            # use tab indentation instead of spaces
            use_tab_indents=1
            ;;
        x)
            # omit the XML header from output
            output=''
            ;;
        :)
            # option argument not specified
            printf "%s: option -" "$0" >&2
            printf "%s requires an argument\n" "${OPTARG}" >&2
            exit 1
            ;;
        \?)
            # invalid option
            printf "%s: invalid option: -%s\n" "$0" "${OPTARG}" >&2
            exit 1
            ;;
        esac
    done

    # shift all processed options
    shift $((OPTIND - 1))

    # check for input file operand and read into variable
    if (($# != 0)); then
        if [[ -f "$1" ]]; then
            input=$(<"$1")
            #IFS= read -r -d '' input <"$1"
        else
            printf "%s: file %s not found\n" "$0" "$1" >&2
            exit 1
        fi
    else
        printf "%s: missing input file operand\n" "$0" >&2
        exit 1
    fi

    # process root value in JSON file
    process_value 1

    # output the generated XML data
    if (($# == 1)); then
        printf "%b" "${output}"
    else
        if ((append_output)); then
            printf "%b" "${output}" >>"$2"
        else
            printf "%b" "${output}" >"$2"
        fi
    fi

}

main "$@"
