#!/bin/zsh
# Renders the RecallOS demo papers into demo/papers/. Needs ImageMagick.
#
# Everything on them is invented: people, shops, serial numbers. Phone numbers
# use a 01700-0000xx placeholder and email and web addresses use the reserved
# .example domain, so a demo tap on Call or Email cannot reach a real person.
set -e
cd "$(dirname "$0")/papers"
F=/System/Library/Fonts/Supplemental/Arial.ttf
B="/System/Library/Fonts/Supplemental/Arial Bold.ttf"

# card FILE ACCENT NAME TITLE COMPANY PHONE EMAIL [ADDRESS]
card() {
  magick -size 1050x600 xc:white -fill "$2" -draw 'rectangle 0,0 26,600' \
    -fill '#141414' -font "$B" -pointsize 56 -annotate +80+110 "$3" \
    -font "$F" -pointsize 36 -annotate +80+170 "$4" \
    -font "$B" -pointsize 46 -annotate +80+290 "$5" \
    -font "$F" -pointsize 34 -annotate +80+410 "$6" -annotate +80+470 "$7" \
    ${8:+-annotate} ${8:++80+530} ${8:+"$8"} "$1.png"
  magick "$1.png" -density 150 "$1.pdf"; rm "$1.png"
}

# paper FILE LINES... where a line is "y|left" or "y|left|right" or "y|B|left"
paper() {
  local out=$1; shift
  local -a args
  args=(-size 1000x1300 xc:white -fill '#141414')
  for line in "$@"; do
    local -a p; p=("${(@s:|:)line}")
    if [[ ${p[2]} == B ]]; then
      args+=(-font "$B" -pointsize 50 -gravity NorthWest -annotate "+70+${p[1]}" "${p[3]}")
    else
      args+=(-font "$F" -pointsize 34 -gravity NorthWest -annotate "+70+${p[1]}" "${p[2]}")
      [[ -n ${p[3]} ]] && args+=(-gravity NorthEast -annotate "+70+${p[1]}" "${p[3]}")
    fi
  done
  magick "${args[@]}" "$out.png"
  magick "$out.png" -density 150 "$out.pdf"; rm "$out.png"
}

# --- Business cards -------------------------------------------------------
card 01-card-print-shop '#B5482E' 'Arif Hossain' 'Owner' 'Padma Print House' \
  '+880 1700 000 001' 'arif@padmaprint.example' 'Dhanmondi, Dhaka'
card 02-card-sponsor '#2E5FB5' 'Nadia Islam' 'Marketing Director' 'Kingfisher Esports Ltd' \
  '+880 1700 000 002' 'nadia@kingfisheresports.example'
card 03-card-caterer-front '#2F8F5B' 'Sumaiya Akter' 'Event Coordinator' 'Shapla Catering Service' \
  '+880 1700 000 003' 'sumaiya@shaplacatering.example'
card 04-card-duplicate-a '#7A4FB5' 'Md. Karim Rahman' 'Sales Officer' 'Meghna Traders' \
  '+880 1700 000 004' 'sales@meghnatraders.example'
card 05-card-duplicate-b '#7A4FB5' 'Md. Karim Rahman' 'Regional Manager' 'Meghna Traders Ltd' \
  '+880 1700 000 005' 'karim.r@meghnatraders.example'

# The other side of the caterer's card. Made to look like a photograph of a
# card on a table, because it goes through the document scanner, which looks
# for a card's edges and mangles a flat image.
magick -size 1050x600 xc:'#FBF7EE' -fill '#2F8F5B' -draw 'rectangle 0,0 1050,26' \
  -fill '#141414' -font "$B" -pointsize 44 -annotate +80+120 'Our services' \
  -font "$F" -pointsize 36 -annotate +80+210 'Weddings and holud' \
  -annotate +80+270 'Corporate lunch boxes' -annotate +80+330 'Birthday parties' \
  -annotate +80+430 'Please order 3 days ahead' _face.png
magick _face.png -background none -rotate -2 \( +clone -background black -shadow 60x18+10+14 \) \
  +swap -background none -layers merge +repage _lift.png
magick -size 1600x1200 xc:'#5A4A3A' -attenuate 0.5 +noise Gaussian -blur 0x3 _table.png
magick _table.png _lift.png -gravity center -composite -attenuate 0.18 +noise Gaussian \
  -blur 0x0.6 -quality 92 03-card-caterer-back.jpg
rm -f _face.png _lift.png _table.png 03-card-caterer-back.png

# A card nothing can read: for Needs attention.
magick -size 1050x600 xc:white -fill '#141414' -font "$B" -pointsize 56 \
  -annotate +80+150 'Illegible Card' -font "$F" -pointsize 40 -annotate +80+300 'Nothing here can be read' \
  -blur 0x22 -attenuate 0.6 +noise Gaussian 06-card-unreadable.png
magick 06-card-unreadable.png -density 150 06-card-unreadable.pdf; rm 06-card-unreadable.png

# --- Receipts and bills ---------------------------------------------------
grocery=('90|B|ANONDO SUPER SHOP' '170|Banani, Dhaka' '260|Invoice No: AS-4432' \
  '320|Date: 03/11/2026' '440|Milk 1L x 2|190.00' '510|Bread|60.00' '580|Rice 1 kg|162.00' \
  '700|Subtotal|412.00' '770|VAT 5%|20.60' '860|Grand Total|432.60' '960|Cash|500.00' '1030|Change|67.40')
paper 07-receipt-grocery "${grocery[@]}"
paper 08-receipt-grocery-second-copy "${grocery[@]}"
paper 09-bill-electricity '90|B|METRO POWER COMPANY' '170|Electricity bill' '260|Bill No: MP-220915' \
  '320|Bill Date: 05/11/2026' '440|Units used: 214' '510|Energy charge|1,120.00' '580|Meter rent|40.00' \
  '650|VAT|85.00' '770|Net Payable|1,245.00'
paper 10-bill-restaurant '90|B|KACCHI CORNER RESTAURANT' '170|Gulshan, Dhaka' '260|Bill No: 8841' \
  '320|Date: 08/11/2026' '440|Kacchi full x 3|1,500.00' '510|Borhani x 3|240.00' '580|Salad|110.00' \
  '700|Net Payable|1,850.00'
paper 11-receipt-dollars '90|B|HARBOR BOOKS' '170|Singapore' '260|Receipt: HB-3307' \
  '320|Date: 06/11/2026' '440|Paperback x 2|USD 24.50' '700|Total|USD 24.50'
paper 12-refund-slip '90|B|JAMUNA TECH MART' '180|B|REFUND RECEIPT' '300|Date: 07/11/2026' \
  '420|Returned: USB hub' '560|Total|400.00'
paper 13-receipt-laptop '90|B|JAMUNA TECH MART' '170|Agargaon, Dhaka' '260|Invoice No: INV-77120' \
  '320|Date: 02/11/2026' '440|Laptop Nimbus Book 14' '500|Serial: NB14X9921' '640|Grand Total|85,000.00'

# --- Warranties -----------------------------------------------------------
paper 14-warranty-laptop '90|B|WARRANTY CARD' '200|Product: Laptop' '270|Brand: Nimbus' \
  '340|Model: Book 14' '410|Serial No: NB14X9921' '480|Warranty: 2 years' '550|Sold by: Jamuna Tech Mart'
paper 15-warranty-fridge '90|B|WARRANTY CARD' '200|Product: Refrigerator' '270|Brand: Frostline' \
  '340|Model: FL 300' '410|Serial No: FL-20455' '480|Valid until: 15/01/2027' '550|Sold by: Cool Home Appliances'
