# **json2xml**

Bash script that parses a JSON file into XML data.

## Installation

Place `json2xml.sh` into desired location and make it executable with
`chmod +x json2xml.sh`.

## Usage

```
./json2xml.sh [options] json_file [xml_file]
```

### Options

```
  -h      Show the help documentation
  -a      Append XML data to output file
  -i N    Set the indentation to N spaces (default: 4)
  -t      Use tab indentation instead of spaces
  -x      Omit the header from the XML data
```

### Examples

```
./json2xml.sh -i 2 sample1.json
./json2xml.sh -t sample2.json output.xml
./json2xml.sh -atx sample3.json output.xml
```

## Sample Output

<details open>

<summary>JSON input</summary>

```json
{
    "name": "Sleeping Kitty",
    "type": "wallpaper",
    "image": {
        "url": "images/kitty.jpg",
        "width": 1920,
        "height": 1080,
        "aspect ratio": 1.778
    },
    "thumbnail": {
        "url": "images/thumbnails/kitty.jpg",
        "width": 160,
        "height": 90
    },
    "metadata": {
        "created": "2025:02:11 11:34:47",
        "modified": "2025:05:09 21:36:21",
        "keywords": {
            "tag": [
                "cat",
                "kitten",
                "kitty",
                "sleeping",
                "wallpaper"
            ]
        }
    },
    "permissions": {
        "read": true,
        "write": false
    }
}
```
</details>

<details open>

<summary>XML output</summary>

```xml
<?xml version="1.0" encoding="UTF-8"?>
<name>Sleeping Kitty</name>
<type>wallpaper</type>
<image>
    <url>images/kitty.jpg</url>
    <width>1920</width>
    <height>1080</height>
    <aspect_ratio>1.778</aspect_ratio>
</image>
<thumbnail>
    <url>images/thumbnails/kitty.jpg</url>
    <width>160</width>
    <height>90</height>
</thumbnail>
<metadata>
    <created>2025:02:11 11:34:47</created>
    <modified>2025:05:09 21:36:21</modified>
    <keywords>
        <tag>cat</tag>
        <tag>kitten</tag>
        <tag>kitty</tag>
        <tag>sleeping</tag>
        <tag>wallpaper</tag>
    </keywords>
</metadata>
<permissions>
    <read>true</read>
    <write>false</write>
</permissions>
```
</details>

## XML Name Handling

While the XML specification permits a large group of Unicode symbol characters
to be used in XML names, this script only permits the valid ASCII characters
listed in the specification.

The first permitted character for an XML name must be an
alphabetic character, a colon, or an underscore:

`NameStartChar ::= [A-Z] | [a-z] | ":" | "_"`

The remaining permitted characters for an XML name may be any valid
character listed above, a digit, a hyphen, or a period:

`NameChar ::= NameStartChar | [0-9] | "-" | "."`

If the first character is not a valid `NameStartChar`, a leading underscore
is added to the name. Any character encountered in the JSON property name that
is not a `NameStartChar` or `NameChar` as defined above is skipped, except for
spaces which are replaced with underscores to preserve the original formatting.
If no valid characters are found, a generic name of `element` will be used for
the XML name.

## Special Character Handling

### XML Character References

There are five special reserved characters in XML.
When these characters are encountered in a JSON string value,
they are replaced with their corresponding XML character reference:

| Character | Reference | Name |
| ---- | ---- | ---- |
| `<` | `&lt;` | Less than sign |
| `>` | `&gt;` | Greater than sign |
| `&` | `&amp;` | Ampersand |
| `"` | `&quot;` | Quotation mark |
| `'` | `&apos;` | Apostrophe |

### JSON Control Characters

When the following three JSON control characters are encountered in a string
value, they are replaced with their corresponding XML character reference:

| Character | Reference | Name |
| ---- | ---- | ---- |
| `\t` | `&#x09;` | Horizontal Tab |
| `\n` | `&#x0A;` | Line Feed |
| `\r` | `&#x0D;` | Carriage Return |

The following three JSON control characters do not require character
references, so their corresponding values are added directly to the XML output.
Note that a Unicode character is represented by the control character `\u`
followed by four hexadecimal digits, as shown in the example below:

| Character | Value | Name |
| ---- | ---- | ---- |
| `\\` | `\` | Reverse Solidus |
| `\/` | `/` | Solidus |
| `\u0394` | `Δ` | Unicode Character |

The following two control characters are valid JSON control characters but have
no valid XML equivalents and therefore are skipped:

| Character | Name |
| ---- | ---- |
| `\b` | Backspace |
| `\f` | Line Feed |

## Error Handling

While parsing the input, the script will actively check for various syntax
errors present in the JSON file. The following five conditions will trigger an
error and terminate processing:

* An object value is missing a required `,` or `}`
* An array value is missing a required `,` or `]`
* A property is missing a required `:` between the name and value
* A string value is missing a terminating `"`
* An invalid numerical value or literal name token was found

No XML data will be generated, and an error message will be output to `stderr`.

An example error message for an improperly terminated array:
```
./json2xml.sh: error in input file: ',' or ']' expected! (Line 36:9)
```

## Test Cases

The following test cases are used to verify proper script operation:

* `test_xml_names.json`: XML Name Handling
* `test_characters.json`: Special Character Handling
* `test_values.json`: JSON Numerical Formats and Literals

The following test cases are used to verify proper error handling:

* `error_object.json`: Object missing terminating `}`
* `error_array.json`: Array missing separating `,`
* `error_colon.json`: Property missing separating `:`
* `error_string.json`: String missing terminating `"`
* `error_value.json`: Numerical value is invalid

These test cases, along with their output results, can be found in the
repository `test cases` folder.

## License

 GNU General Public License v3.0

## References

[ECMA-404 The JSON Data Interchange Standard](https://www.ecma-international.org/publications-and-standards/standards/ecma-404/)

[W3C Extensible Markup Language (XML) 1.0 (Fifth Edition)](https://www.w3.org/TR/xml/)
