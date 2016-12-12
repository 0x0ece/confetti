#!/bin/bash

function parse_yaml {
  # http://stackoverflow.com/a/21189044/1326313
  # TODO: remove dependency on AWK?
  local prefix=$1
  local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
  sed -ne "s|^\($s\):|\1|" \
       -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
       -e "s|^\($s\)\([^:#$s]*\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" \
       -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" /dev/stdin |
  awk -F$fs '{
     indent = length($1)/2;
     vname[indent] = $2;
     for (i in vname) {if (i > indent) {delete vname[i]}}
     if (length($3) > 0) {
        vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("|")}
        printf("%s%s%s|%s\n", "'$prefix'",vn, $2, $3);
     }
  }'
}

function print_and_exec {
  # print the cmd before exec with a hack for sed params
  # set -x it too verbose
  # also, can't put it in a subshell or we loose exported variables
  echo "$*" | sed -e "s/-e\ \([^ ]*\)\ /-e '\1' /"
  $*
}


CONFIG=$(parse_yaml)

ARGS=${*-default}
for ARG in $ARGS
do
  echo "# $0 $ARG"
  for LINE in $CONFIG
  do
    LINEESC=$(echo "$LINE" | sed -e 's/\\/\\\\\\\\/g')
    IFS='|' read REALM CMD KEY VALUE <<< "$LINEESC"
    if [ "$ARG" == "$REALM" ]
    then
      case $CMD in
        "env")
          # set envoriment variable KEY=VALUE
          print_and_exec export $KEY=${!KEY:-"$VALUE"}
          ;;
        "copy")
          # copy VALUE(s) into KEY
          # - KEY can be a file or a directory
          # - VALUE can be a single file or multiple files
          print_and_exec cp $VALUE $KEY
          ;;
        *)
          # modify config in FILE, replacing KEY with VALUE
          # - KEY is literal, i.e. $ is escaped
          # - VALUE is expanded, i.e. $ means bash variable
          FILE=CMD
          if [ "${VALUE:0:1}" == '$' ]
          then
            VARNAME=${VALUE:1}
            SEDVALUE=${!VARNAME}
          else
            SEDVALUE=$VALUE
          fi
          print_and_exec sed -i -e "s|$KEY|$SEDVALUE|g" $CMD
          ;;
      esac
    fi
  done
done
