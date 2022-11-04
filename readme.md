# CViT - Chromosome Viewing Tool #

Ethalinda Cannon
ethy@a415software.com


**Current release: 3/15/17 - Release 1.3**


CViT is a Perl script used to quickly generate images that show features on 
genomic sequence. It is intentionally simplistic and low-tech; there are 
limitless possibilities for how one might view such data and CViT is 
optimized for speed and ease of use over high-tech features.

Input is one or more files in GFF3 format.
(see http://www.sequenceontology.org/gff3.shtml)
One of these files must contain records describing one or more "chromosomes" 
(which could represent a psuedomolecule, BAC, contig, linkage group, any 
sort of contiguous stretch of DNA, or even a protein structure). These 
"chromosomes" are the backbone that the features are placed on.

Output is a PNG or SVG image.

CViT can be wrapped in other Perl scripts to extend its capability, or 
called by web pages to generate on-demand images. For example, BLAST 
hits can be displayed on a whole-genome view and displayed in a web 
browser.

Most aspects of the image can be modified without touching the code. 
See the ini file, config/cvit.ini.

Note that all names, types, and attributes in the GFF are case-sensitive.

**Cite CViT:** doi: [10.1155/2011/373875](http://dx.doi.org/10.1155/2011/373875)

**A Javascript version of CViT is available [here](https://github.com/LegumeFederation/cvitjs).**


Requirements:
-------------
Perl 5.8.8+

GD library (http://www.libgd.org)

Perl libraries:
  + GD
  + GD::Arrow
  + GD::Image
  + GD::Text
  + GD::SVG
  + SVG
  + Config::IniFiles
  + Data::Dumper


Installation:
-------------
Installation basically involves installing the required C libraries (libgd), followed by the Perl libraries. Below are two options for accomplishing this; other routes are possible, depending on your environment.

**Option 1**, suitable for Unix/Linux environments, including macOS, where the [conda](https://docs.conda.io/en/latest/) package manager is available:

    conda create -c conda-forge -c bioconda -n cvit perl-gd-svg
    source activate cvit

    cpan install Config::IniFiles GD::Arrow GD::Text

    git clone https://github.com/ekcannon/CViT.git
    cd CViT
    [Prepare your data and cvit.ini, then call ./cvit.pl with suitable arguments]

**Option 2**, suitable for installation on macOS and Linux. This employs HomeBrew to do the initial installation of C libraries and perl (for integration of CPAN), followed by HomeBrew's CPAN for installing the perl libraries:

    brew install libgd
    brew install perl
    brew install pkg-config

    cpan install GD::SVG GD::Arrow GD::Text

    git clone https://github.com/ekcannon/CViT.git
    cd CViT
    [Prepare your data and cvit.ini, then call ./cvit.pl with suitable arguments]


Files:
------
  + cvit.pl        - the main scripts
  + cvit.log       - tracks behavior and errors
  + config/        - contains one or more .ini files
  + documentation/ - how to use CViT
  + examples/      - examples of CViT use
  + fonts/         - contains truetype fonts
  + pkgs/
     + ColorManager.pm  - manages colors
     + ConfigManager.pm - manages the drawing options from .ini file
     + CvitImage.pm     - holds base image
     + CvitLib.pm       - library of general purpose functions
     + errorlog.pm      - writes to cvit.log
     + FontManager.pm   - manages fonts
     + GFFManager.pm    - manages the GFF records
     + GlyphCalc.pm     - calculates positions for all the glyphs
     + GlyphDrawer.pm   - draws glyphs onto base image
  + rgb.txt        - list of possible colors

See config/cvit.ini and the examples for more information about how to use CViT.


Credits:
--------
CViT was designed and developed by Ethalinda and Steven Cannon. The icon was 
designed by Melanie Shaw.

********************************************************************************

Changelog:
----------
  + **1.3**    - Fixed bugs in glyph options wherein settings from the previous glyph in the set were reused for the second rather than being replaced. This was only  true if one glyph type was a "measure". MOVED TO GITHUB. **Older versions in SourceForge: https://sourceforge.net/projects/cvit/**
  + **1.2**    - Fixed bugs in coordinate systems with floating point values and placement of glyphs when chromosomes don't share the same start coordinate.
  + **1.1**    - Code clean-up, more and better error reporting, variable chromosome placement, many bug fixes. Added support for SVG images.
  + **1.0**    - First stable release. Minor bug fixes. 'Measure' records can be displayed as either ranges or positions. Value for 'measure' records can be distance from chromosome as well as heatmap colors and histograms. Added web utility cvit-maker to distribution.
  + **b2.0**   - Made more consistent, added several drawing options, all options in .ini file can be changed on the command line.
  + **b1.3**   - Improved ruler, including addition of fractional units (e.g. Cytological McClintock units). Added ability to increase space to left or right of the chromosome set. Writes only one label if multiple labeled glyphs are printed at one location. Bug fixes.
  + **b1.2**   - Added grayscale colors for heatmaps, better error reporting, many bug fixes.
  + **b1.1**   - Truetype font support and better placement of text, features for cytogentic maps, ruler can run backward
  + **b1.0.1** - A few minor bug fixes. Added a legend image and file of feature  coordinates.
  + **b1.0**   - Initial SourceForge release
