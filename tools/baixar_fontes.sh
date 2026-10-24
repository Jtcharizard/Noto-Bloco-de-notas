#!/bin/bash
# Baixa as fontes do app e, com --leve, deixa cada uma bem menor:
# fixa o peso normal (fontes variáveis) e mantém só as letras usadas em português.
set -e
mkdir -p assets/fonts
curl -fL https://raw.githubusercontent.com/google/fonts/main/ofl/poppins/Poppins-Regular.ttf -o assets/fonts/Poppins-Regular.ttf
curl -fL https://raw.githubusercontent.com/google/fonts/main/ofl/poppins/Poppins-Bold.ttf -o assets/fonts/Poppins-Bold.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/montserrat/Montserrat%5Bwght%5D.ttf' -o assets/fonts/Montserrat.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/playfairdisplay/PlayfairDisplay%5Bwght%5D.ttf' -o assets/fonts/PlayfairDisplay.ttf
curl -fL https://raw.githubusercontent.com/google/fonts/main/ofl/bebasneue/BebasNeue-Regular.ttf -o assets/fonts/BebasNeue-Regular.ttf
curl -fL https://raw.githubusercontent.com/google/fonts/main/ofl/lobster/Lobster-Regular.ttf -o assets/fonts/Lobster-Regular.ttf
curl -fL https://raw.githubusercontent.com/google/fonts/main/ofl/pacifico/Pacifico-Regular.ttf -o assets/fonts/Pacifico-Regular.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/caveat/Caveat%5Bwght%5D.ttf' -o assets/fonts/Caveat.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/dancingscript/DancingScript%5Bwght%5D.ttf' -o assets/fonts/DancingScript.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/oswald/Oswald%5Bwght%5D.ttf' -o assets/fonts/Oswald.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/raleway/Raleway%5Bwght%5D.ttf' -o assets/fonts/Raleway.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/lora/Lora%5Bwght%5D.ttf' -o assets/fonts/Lora.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/Nunito%5Bwght%5D.ttf' -o assets/fonts/Nunito.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/quicksand/Quicksand%5Bwght%5D.ttf' -o assets/fonts/Quicksand.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/rubik/Rubik%5Bwght%5D.ttf' -o assets/fonts/Rubik.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/cinzel/Cinzel%5Bwght%5D.ttf' -o assets/fonts/Cinzel.ttf
curl -fL https://raw.githubusercontent.com/google/fonts/main/ofl/bangers/Bangers-Regular.ttf -o assets/fonts/Bangers-Regular.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/comfortaa/Comfortaa%5Bwght%5D.ttf' -o assets/fonts/Comfortaa.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf' -o assets/fonts/Inter.ttf
curl -fL https://raw.githubusercontent.com/google/fonts/main/ofl/firasans/FiraSans-Regular.ttf -o assets/fonts/FiraSans-Regular.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/firacode/FiraCode%5Bwght%5D.ttf' -o assets/fonts/FiraCode.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/josefinsans/JosefinSans%5Bwght%5D.ttf' -o assets/fonts/JosefinSans.ttf
curl -fL https://raw.githubusercontent.com/google/fonts/main/ofl/abrilfatface/AbrilFatface-Regular.ttf -o assets/fonts/AbrilFatface-Regular.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/fredoka/Fredoka%5Bwdth,wght%5D.ttf' -o assets/fonts/Fredoka.ttf
curl -fL https://raw.githubusercontent.com/google/fonts/main/ofl/kalam/Kalam-Regular.ttf -o assets/fonts/Kalam-Regular.ttf
curl -fL https://raw.githubusercontent.com/google/fonts/main/apache/satisfy/Satisfy-Regular.ttf -o assets/fonts/Satisfy-Regular.ttf
curl -fL https://raw.githubusercontent.com/google/fonts/main/ofl/righteous/Righteous-Regular.ttf -o assets/fonts/Righteous-Regular.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/spacegrotesk/SpaceGrotesk%5Bwght%5D.ttf' -o assets/fonts/SpaceGrotesk.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/manrope/Manrope%5Bwght%5D.ttf' -o assets/fonts/Manrope.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/urbanist/Urbanist%5Bwght%5D.ttf' -o assets/fonts/Urbanist.ttf
curl -fL https://raw.githubusercontent.com/google/fonts/main/ofl/dmserifdisplay/DMSerifDisplay-Regular.ttf -o assets/fonts/DMSerifDisplay-Regular.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/librebaskerville/LibreBaskerville%5Bwght%5D.ttf' -o assets/fonts/LibreBaskerville-Regular.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/apache/robotoslab/RobotoSlab%5Bwght%5D.ttf' -o assets/fonts/RobotoSlab.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/merriweather/Merriweather%5Bopsz,wdth,wght%5D.ttf' -o assets/fonts/Merriweather.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ufl/ubuntu/Ubuntu-Regular.ttf' -o assets/fonts/Ubuntu.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/ptsans/PT_Sans-Web-Regular.ttf' -o assets/fonts/PTSans.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/inconsolata/Inconsolata%5Bwdth,wght%5D.ttf' -o assets/fonts/Inconsolata.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/dosis/Dosis%5Bwght%5D.ttf' -o assets/fonts/Dosis.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/anton/Anton-Regular.ttf' -o assets/fonts/Anton.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/shadowsintolight/ShadowsIntoLight.ttf' -o assets/fonts/ShadowsIntoLight.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/amaticsc/AmaticSC-Regular.ttf' -o assets/fonts/AmaticSC.ttf
curl -fL 'https://raw.githubusercontent.com/google/fonts/main/ofl/indieflower/IndieFlower-Regular.ttf' -o assets/fonts/IndieFlower.ttf

if [ "$1" = "--leve" ]; then
  pip install --quiet fonttools brotli >/dev/null 2>&1 || pip install --quiet --break-system-packages fonttools
  python3 tools/fontes_leves.py assets/fonts/*.ttf
fi
