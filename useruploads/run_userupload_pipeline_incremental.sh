#!/usr/bin/env bash

USERUPLOADS_DIR="/usr/local/textpresso/useruploads"

for user_dir in ${USERUPLOADS_DIR}/*
do
    cd ${user_dir}
    username=${PWD##*/}
    mkdir -p ${user_dir}/tpcas
    mkdir -p ${user_dir}/tmp/cas1
    mkdir -p ${user_dir}/tmp/cas2
    mkdir -p ${user_dir}/useruploads/${username}
    touch ${user_dir}/tpcas/processed_files.txt
    touch ${user_dir}/tpcas/tokenized_files.txt
    tmpfile=$(mktemp)
    grep -vxf ${user_dir}/tpcas/processed_files.txt <(ls -1 ${user_dir}/uploadedfiles) > ${tmpfile}
    if [[ $(grep ".pdf" ${tmpfile} | wc -l | awk '{print $1}') != "0" ]]
    then
        articles2cas -t 1 -i uploadedfiles -o useruploads/${username} -l <(grep ".pdf" ${tmpfile})
    fi
    if [[ $(grep ".nxml" ${tmpfile} | wc -l | awk '{print $1}') != "0" ]]
    then
        articles2cas -t 2 -i ${user_dir}/uploadedfiles -o useruploads/${username} -l <(grep ".nxml" ${tmpfile})
    fi
    # TODO process compressed archives
    mv useruploads/${username}/* ${user_dir}/tpcas/
    rm -rf useruploads
    cat ${tmpfile} >> ${user_dir}/tpcas/tokenized_files.txt
    grep -xf <(sed -e 's/\.[^.]*$//' ${tmpfile}) <(ls ${user_dir}/tpcas/) | xargs -I {} cp ${user_dir}/tpcas/{}/{}.tpcas  ${user_dir}/tmp/cas1
    if [[ $(ls ${user_dir}/tmp/cas1/ | wc -l | awk '{print $0}') != "0" ]]
    then
        runAECpp /usr/local/uima_descriptors/TpLexiconAnnotatorFromPg.xml -xmi ${user_dir}/tmp/cas1 ${user_dir}/tmp/cas2
    fi
    for tpcas2_file in $(ls ${user_dir}/tmp/cas2/*)
    do
        mv ${tpcas2_file} ${user_dir}/tpcas/$(basename ${tpcas2_file} | sed -e 's/\.[^.]*$//')
        if [[ -f ${user_dir}/uploadedfiles/$(basename ${tpcas2_file} | sed -e 's/\.[^.]*$//').bib ]]
        then
            cp ${user_dir}/uploadedfiles/$(basename ${tpcas2_file} | sed -e 's/\.[^.]*$//').bib ${user_dir}/tpcas/$(basename ${tpcas2_file} | sed -e 's/\.[^.]*$//')
        fi
        gzip ${user_dir}/tpcas/$(basename ${tpcas2_file} | sed -e 's/\.[^.]*$//')/$(basename ${tpcas2_file})
    done
    rm -rf ${user_dir}/tmp/
    cat ${tmpfile} >> ${user_dir}/tpcas/processed_files.txt
    rm ${tmpfile}
    mkdir -p /usr/local/textpresso/tpcas/useruploads/${username}
    cd tpcas
    find . -mindepth 1 -maxdepth 1 -type d | xargs -I {} ln -s ${user_dir}/tpcas/{} /usr/local/textpresso/tpcas/useruploads/${username}/{}
    if [[ ! -f ${user_dir}/luceneindex ]]
    then
        mkdir -p ${user_dir}/luceneindex
        cas2index -i ${user_dir}/tpcas -o ${user_dir}/luceneindex -s 300000 -e
    fi
done