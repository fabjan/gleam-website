#!/bin/sh

# This script uses the gleam compiler CLI to generate markdown
# from its own help output.

set -e

trim() {
  sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
}

if gleam help | grep -q 'Usage:'; then
  # Updating should be easy, just change the patterns to match the new output.
  # Try it, remove this error, and see what the diff looks like!
  echo >&2 "Looks like gleam is using a clap version other than 3, please update this script."
  exit 1
fi

echo >&2 "Assuming clap version 3 when parsing help output."
HEADING_PATTERN='^[A-Z][A-Z]*:'
SUBCOMMAND_HEADING='^SUBCOMMANDS:'
USAGE_HEADING='^USAGE:'
OPTIONS_HEADING='^OPTIONS:'

drop_headings() {
  grep -v "$HEADING_PATTERN"
}

find_description() {
  # all lines up to the first heading, except the first line
  sed -n "2,/$HEADING_PATTERN/p" | drop_headings | trim
}

find_subcommands() {
  # all lines between the SUBCOMMANDS heading and the next heading
  sed -n "/$SUBCOMMAND_HEADING/,/$HEADING_PATTERN/p" | drop_headings | trim | cut -d' ' -f1
}

find_usage() {
  # all lines between the USAGE heading and the next heading
  sed -n "/$USAGE_HEADING/,/$HEADING_PATTERN/p" | drop_headings | trim
}

find_options() {
  # grep returns 1 if no matches, we need to ignore that for the pipeline to work.
  set +e
  # All lines between the OPTIONS heading and the next heading,
  # except tje --help option as it is not useful in these docs.
  # Option descriptions can span multiple lines, hence the funky '§' business to join them.
  sed -n "/$OPTIONS_HEADING/,/$HEADING_PATTERN/p" | drop_headings | tr '\n' '§' | sed -E 's/§ *-/\n-/g' | sed 's/§ */ /g' | trim | grep -v -- '--help'
  set -e
}

# Render markdown help for a subcommand, or a subcommand under it.
show_docs() {
  subcommand="$1"
  subsubcommand="$2"

  if [ -z "$subsubcommand" ]; then
    help=$(gleam help "$subcommand")
    heading="## \`$subcommand\`"
  else
    help=$(gleam help "$subcommand" "$subsubcommand")
    heading="### \`$subcommand $subsubcommand\`"

    subsubsubcommand=$(echo "$help" | find_subcommands)
    if [ -n "$subsubsubcommand" ]; then
      echo >&2 "Subcommand \`$subcommand $subsubcommand\` has subcommands, this is not supported"
      exit 1
    fi

  fi

  description=$(echo "$help" | find_description)
  usage=$(echo "$help" | find_usage)
  options=$(echo "$help" | find_options)

  echo
  echo "$heading"
  echo
  echo \`"$usage"\`
  echo
  echo "$description"
  echo
  if [ -n "$options" ]; then
    echo "| Option | Description |"
    echo "| ------ | ----------- |"
    echo "$options" | sed 's/^/| \`/' | sed -E 's/(  +|$)/\`| /'
  fi
}

cat <<EOF
---
title: Command line reference
subtitle: Getting Gleam things done in the terminal
layout: page
---

<!-- This file is automatically generated by \`writing-gleam/command-line-reference.sh\` -->

The \`gleam\` command uses subcommands to access different parts of the functionality:
EOF

# Note: lsp is a "hidden" command so it will not be shown by `gleam help`
subcommands=$(gleam help | find_subcommands)

for subcommand in $subcommands; do

  show_docs "$subcommand"

  for subsubcommand in $(gleam help "$subcommand" | find_subcommands); do

    if [ "$subsubcommand" = "help" ]; then
      continue
    fi

    show_docs "$subcommand" "$subsubcommand"

  done

done
