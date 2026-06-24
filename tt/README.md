# Tiny Tapeout tools

Tools used mostly by the Tiny Tapeout GitHub Actions

## Setup

```
pip install -r requirements.txt
pre-commit install
```

On macOS, some third-party libraries are required:

```
brew install libpng qhull cairo
```

## Documentation

* checks that basic fields are present in the info.yaml
* create a PDF data sheet for this one design
* create SVG and PNG renders of the project's GDS

## Reports

* routing & utilisation
* yosys warnings
* standard cell usage and summary

## Configuration

* creates a little TCL shim that tells LibreLane where the source is and the name of the top module
* makes sure the top module is not called 'top'
* if you have LibreLane installed locally, then you can harden the design with --harden
