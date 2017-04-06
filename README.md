# pdf-417

```pdf-417``` is a Ruby gem that allows the creation of simple PDF417 barcodes. Using this gem, you can easily generate PNG images of simple PDF417 barcodes.

## Usage

Simply call the class method ```PDF417.to_png(file, text)```. Methods also exist to deal with the object directly.

## Example

```ruby
require 'pdf-417'

PDF417.to_png("sample.png", "This is my PDF417 barcode!")
```

## Result

The above example produces:

![Sample PDF417 barcode](/sample.png?raw=true "Sample PDF417 barcode")

## Inspiration

* https://github.com/bkuzmic/pdf417-js
* http://www.tcpdf.org/

## License

This software is licensed under terms of the MIT License.
