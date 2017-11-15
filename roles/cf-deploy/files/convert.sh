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

    if [[ $LINE == *version:* ]]; then
#        if [[ ${RELEASES} == true ]]; then
#            echo $LINE | sed 's/version: .*/version: latest/g'  >> $CF_DEPLOYMENT
#        fi

        if [[ ${STEMCELLS} == true ]]; then
            echo "  name: bosh-alicloud-kvm-ubuntu-trusty-go_agent" >> $CF_DEPLOYMENT
            echo $LINE | sed "s/version: .*/version: $2/g"  >> $CF_DEPLOYMENT
        fi
    elif [[ $LINE == *os:* && ${STEMCELLS} == true ]]; then
        continue
#    elif [[ $LINE == *url:* && ${RELEASES} == true* ]]; then
#        continue
#    elif [[ $LINE == *sha1:* && ${RELEASES} == true* ]]; then
#        continue
    else
        echo $LINE >> $CF_DEPLOYMENT
    fi
done
