#!/bin/sh

usage() { echo "Usage: $0 [-s path_to_source_xml_zip_files] [-t target_path_for_export] [-u unmatched_to_arks_path]" 1>&2; exit 1; }

while getopts ":s:t:u:" o; do
    case "${o}" in
        s)
            SOURCEDIR=${OPTARG}
            ;;
        t)
            TARGETDIR=${OPTARG}
            ;;
        u)
            UNMATCHEDDIR=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

shift "$(( OPTIND - 1 ))"

if [ -z "$SOURCEDIR" ] || [ -z "$TARGETDIR" ] || [ -z "$UNMATCHEDDIR" ]; then
        echo 'Error: source, target, or unmatched argument(s) not set' >&2
        usage
fi

echo "Processing XML files... (step 1 of 2)"

for f in $SOURCEDIR/*.xml; do export MARC_PATH="$SOURCEDIR/$(basename "${f%.}")"; export OUTPUT_MARC_PATH="$TARGETDIR/$(basename "${f%.}")"; export UNCHANGED_MARC_PATH="$UNMATCHEDDIR/$(basename "${f%.}")"; bundle exec thor etd_processor:insert_arks -f $MARC_PATH -o $OUTPUT_MARC_PATH -m $UNCHANGED_MARC_PATH; done

echo "Process complete.  Output saved to $TARGETDIR. Thank you! (step 2 of 2)"
