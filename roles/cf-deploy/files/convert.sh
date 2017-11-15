#!/usr/bin/env bash


CF_DEPLOYMENT=cf-deployment-$1.yml
RELEASES=false
STEMCELLS=false

touch ${CF_DEPLOYMENT}
echo "" > ${CF_DEPLOYMENT}
IFS=
OIFS=$IFS

cat $3 | while read LINE
do
    if [[ $LINE == releases: ]]; then
        RELEASES=true
        STEMCELLS=false
    fi

    if [[ $LINE == stemcells: ]]; then
        RELEASES=false
        STEMCELLS=true
    fi

    if [[ ${STEMCELLS} == true ]]; then
        if [[ $LINE == *version:* ]]; then
            echo "  name: bosh-alicloud-kvm-ubuntu-trusty-go_agent" >> $CF_DEPLOYMENT
            echo $LINE | sed "s/version: .*/version: $2/g"  >> $CF_DEPLOYMENT
        elif [[ $LINE == *os:* ]]; then
            continue
        else
            echo $LINE >> $CF_DEPLOYMENT
        fi
    else
        echo $LINE >> $CF_DEPLOYMENT
    fi
done
