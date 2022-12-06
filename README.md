# ETD Processor

## Getting Started

```bash
$ bundle install
```

## Usage

First, please download the MARC record export into the directory `downloads/`.

Then, in order to generate the MARC records with the updated ARKs, please invoke the following:

```bash
$ export MARC_PATH="downloads/export.mrc"
$ export OUTPUT_MARC_PATH="output/updated.mrc"
$ export UNCHANGED_MARC_PATH="output/unchanged.mrc"
$ bundle exec thor etd_processor:insert_arks -f $MARC_PATH -o $OUTPUT_MARC_PATH -m $UNCHANGED_MARC_PATH
```

This generates two files, with `$OUTPUT_MARC_PATH` containing the MARC records with the located ARK URLs, and `$UNCHANGED_MARC_PATH` containing the MARC records which could not be matched to any known DSpace ARKs.

Should one only desire the MARC records with the matched DSpace ARKs, the following invocation will suffice:

```bash
$ export MARC_PATH="downloads/export.mrc"
$ export OUTPUT_MARC_PATH="output/updated.mrc"
$ bundle exec thor etd_processor:insert_arks -f $MARC_PATH -o $OUTPUT_MARC_PATH
```

Should one need to use an alternate DSpace URL, this can be provided using the following:

```bash
$ export MARC_PATH="downloads/export.mrc"
$ export OUTPUT_MARC_PATH="output/updated.mrc"
$ export DSPACE_URL="http://my.dspace.org/"
$ bundle exec thor etd_processor:insert_arks -f $MARC_PATH -o $OUTPUT_MARC_PATH -d $DSPACE_URL
```

