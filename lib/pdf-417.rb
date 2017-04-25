require "constants"

module Enumerable
  def probe
    out = nil
    each_with_index {|val, i| out = yield(val, i) and break}
    out
  end
end

class PDF417
  def initialize(str=nil)
    @tall = 4 # row height in module units
    @wbyh = 2 # barcode's width/height
    @pads = 2 # padding around barcode

    @str = str # string to encode
    @cws = nil # codeword array
    @bar = nil # barcode pattern
  end

  def encode(str=nil)
    str = str ? (@str = str) : @str
    all = str.split('')
    max = all.size - 1
    ary = TEXT_MODE[cur = nxt = 0]
    out = []

    # map to text submodes
    all.each_with_index do |chr, pos|
      unless val = ary.index(ord = chr.ord)
        if nxt = TEXT_MODE.probe {|row, nxt| nxt if (nxt != cur) && (val = row.index(ord)) }
          if (nxt == 3 || (nxt == 0 && cur == 1)) && (pos == max || ary.index(all[pos + 1].ord))
            out.push(nxt == 3 ? 29 : 27) # only shift modes for the next character
          else
            out.concat(TEXT_JUMP["#{cur}#{nxt}"]) # jump to new mode
            ary = TEXT_MODE[cur = nxt]
          end
        end
      end
      out.push val
    end
    out.push(29) unless out.size.even?

    # map to codewords
    @cws = out.each_slice(2).map {|a,b| a * 30 + b }
  end

  def get_ecl(cnt)
    case
      when cnt <  41 then 2
      when cnt < 161 then 3
      when cnt < 321 then 4
      when cnt < 864 then 5
    else                  6
    end
  end

  def get_ecc(cws, ecl)
    ecc = REED_SOLO[ecl]
    max = (2 << ecl) - 1
    ecw = [0] * (max + 1)
    cws.each do |val|
      key = (val + ecw[max]) % 929
      max.downto(0) {|pos| ecw[pos] = ((pos == 0 ? 0 : ecw[pos - 1]) + (929 - (key * ecc[pos]) % 929)) % 929 }
    end
    ecw.map! {|val| val == 0 ? val : 929 - val}
    ecw.reverse
  end

  def generate

    # convert content to codewords
    cws = encode(@str)
    cnt = cws.size; raise "ERROR: Max codeword count is 925, you have #{cnt}" if cnt > 925
    ecl = get_ecl(cnt)
    err = 2 << ecl
    nce = cnt + err + 1

    # find optimal columns using the quadratic equation [-b ± √(b²-4ac)] / 2a
    col = ((Math.sqrt(69 * 69 + 4 * 17 * nce * @tall * @wbyh) - 69) / (2 * 17)).round
    col = col < 1 ? 1 : 30 unless col.between?(1, 30)
    row = (nce / col.to_f).ceil
    tot = col * row
    unless row.between?(3, 90)
      row = row < 3 ? 3 : 90
      col = (tot / row.to_f).ceil # why not (nce / col.to_f).ceil ??
      tot = col * row
    end
    if tot > 928 # adjust dimensions to fit
      col, row = (@wbyh - (17.0 * 29 / 32)).abs < (@wbyh - (17.0 * 16 / 58)).abs ? [29, 32] : [16, 58]
      tot = col * row # 928
    end

    # calculate padding and prepend the symbol length descriptor
    (pad = tot - nce) > 0 and cws.concat([900] * pad)
    cws.unshift(tot - err) # same as (cnt + pad + 1) ?

    # append error correction codewords
    ecw = get_ecc(cws, ecl)
    cws.concat(ecw)

    # create barcode array
    bar = []
    cid = 0
    ind = 0
    pos = 0

    # side bars
    lbar = '0' * @pads + START_CODE
    rbar = STOP_CODE + '0' * @pads

    row.times do |r|
      key = 30 * (r / 3)

      # left side
      out = lbar + ('%17b' % CODE_WORD[cid][case cid
        when 0 then key + (row - 1) / 3
        when 1 then key + (row - 1) % 3 + (ecl * 3)
        when 2 then key + (col - 1)
      end])

      # data portion
      col.times do |c|
        out << ('%17b' % CODE_WORD[cid][cws[pos]])
        pos += 1
      end

      # right side
      out += ('%17b' % CODE_WORD[cid][case cid
        when 0 then key + (col - 1)
        when 1 then key + (row - 1) / 3
        when 2 then key + (row - 1) % 3 + (ecl * 3)
      end]) + rbar

      # add a row
      @tall.times { bar << out }

      # next cluster
      cid = (cid += 1) % 3
    end

    # top and bottom quiet zones
    zone = '0' * (col * 17 + 69 + 2 * @pads) # pad, start, lri, cols, rri, stop, pad
    @pads.times { bar.unshift zone } # top quiet zone
    @pads.times { bar.push    zone } # bottom quiet zone

    # stash barcode
    @bar = bar
    self
  end

  def to_png(opts = {})
    ary = @bar or raise "no barcode available"

    require "chunky_png" unless defined?(ChunkyPNG)

    opts[:x_scale] ||=  1
    opts[:y_scale] ||=  1 # 3
    opts[:margin ] ||= 10

    full_width  = (ary.first.size * opts[:x_scale]) + (opts[:margin] * 2)
    full_height = (ary.size       * opts[:y_scale]) + (opts[:margin] * 2)

    canvas = ChunkyPNG::Image.new(full_width, full_height, ChunkyPNG::Color::WHITE)

    x, y = opts[:margin], opts[:margin]
    dots = ary.map {|l| l.split('').map {|c| c == '1' }}
    dots.each do |line|
      line.each do |bar|
        if bar
          x.upto(x + (opts[:x_scale] - 1)) {|xx|
            y.upto(y + (opts[:y_scale] - 1)) {|yy|
              canvas[xx,yy] = ChunkyPNG::Color::BLACK
            }
          }
        end
        x += opts[:x_scale]
      end
      y += opts[:y_scale]
      x = opts[:margin]
    end

    canvas.to_datastream.to_s
  end

  def self.to_png(file, str)
    if out = new(str).generate.to_png()
      File.write(file, out)
    end
  end
end

# PDF417.to_png("sample.png", "This is my PDF417 barcode!")
