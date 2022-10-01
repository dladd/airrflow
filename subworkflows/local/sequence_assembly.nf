#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/



// Rmarkdown report file
ch_report_rmd = Channel.fromPath(params.report_rmd, checkIfExists: true)
ch_report_css = Channel.fromPath(params.report_css, checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//CHANGEO
include { CHANGEO_MAKEDB } from '../../modules/local/changeo/changeo_makedb'
include { CHANGEO_PARSEDB_SPLIT } from '../../modules/local/changeo/changeo_parsedb_split'
include { CHANGEO_PARSEDB_SELECT } from '../../modules/local/changeo/changeo_parsedb_select'
include { CHANGEO_CONVERTDB_FASTA } from '../../modules/local/changeo/changeo_convertdb_fasta'

//SHAZAM
include { SHAZAM_THRESHOLD } from '../../modules/local/shazam/shazam_threshold'

//CHANGEO
include { CHANGEO_DEFINECLONES } from '../../modules/local/changeo/changeo_defineclones'
include { CHANGEO_CREATEGERMLINES } from '../../modules/local/changeo/changeo_creategermlines'
include { CHANGEO_BUILDTREES } from '../../modules/local/changeo/changeo_buildtrees'

//ALAKAZAM
include { ALAKAZAM_LINEAGE } from '../../modules/local/alakazam/alakazam_lineage'
include { ALAKAZAM_SHAZAM_REPERTOIRES } from '../../modules/local/alakazam/alakazam_shazam_repertoires'

//LOG PARSING
include { PARSE_LOGS } from '../../modules/local/parse_logs'

// Local: Sub-workflows
include { FASTQ_INPUT_CHECK           } from '../../subworkflows/local/fastq_input_check'
include { MERGE_TABLES_WF       } from '../../subworkflows/local/merge_tables_wf'
include { PRESTO_UMI            } from '../../subworkflows/local/presto_umi'
include { PRESTO_SANS_UMI            } from '../../subworkflows/local/presto_sans_umi'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC                      } from '../../modules/nf-core/modules/fastqc/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/


workflow SEQUENCE_ASSEMBLY {

    take:
    ch_input // channel:

    main:

    // Validate params
    if (!params.library_generation_method) {
        exit 1, "Please specify a library generation method with the `--library_generation_method` option."
    }

    // Validate library generation method parameter
    if (params.library_generation_method == 'specific_pcr_umi'){
        if (params.vprimers)  {
            ch_vprimers_fasta = Channel.fromPath(params.vprimers, checkIfExists: true)
        } else {
            exit 1, "Please provide a V-region primers fasta file with the '--vprimers' option when using the 'specific_pcr_umi' library generation method."
        }
        if (params.cprimers)  {
            ch_cprimers_fasta = Channel.fromPath(params.cprimers, checkIfExists: true)
        } else {
            exit 1, "Please provide a C-region primers fasta file with the '--cprimers' option when using the 'specific_pcr_umi' library generation method."
        }
        if (params.race_linker)  {
            exit 1, "Please do not set '--race_linker' when using the 'specific_pcr_umi' library generation method."
        }
        if (params.umi_length < 2)  {
            exit 1, "The 'specific_pcr_umi' library generation method requires setting the '--umi_length' to a value greater than 1."
        }
    } else if (params.library_generation_method == 'specific_pcr') {
        if (params.vprimers)  {
            ch_vprimers_fasta = Channel.fromPath(params.vprimers, checkIfExists: true)
        } else {
            exit 1, "Please provide a V-region primers fasta file with the '--vprimers' option when using the 'specific_pcr' library generation method."
        }
        if (params.cprimers)  {
            ch_cprimers_fasta = Channel.fromPath(params.cprimers, checkIfExists: true)
        } else {
            exit 1, "Please provide a C-region primers fasta file with the '--cprimers' option when using the 'specific_pcr' library generation method."
        }
        if (params.race_linker)  {
            exit 1, "Please do not set '--race_linker' when using the 'specific_pcr' library generation method."
        }
        if (params.umi_length > 0)  {
            exit 1, "Please do not set a UMI length with the library preparation method 'specific_pcr'. Please specify instead a method that suports umi."
        } else {
            params.umi_length = 0
        }
    } else if (params.library_generation_method == 'dt_5p_race_umi') {
        if (params.vprimers) {
            exit 1, "The oligo-dT 5'-RACE UMI library generation method does not accept V-region primers, please provide a linker with '--race_linker' instead or select another library method option."
        } else if (params.race_linker) {
            ch_vprimers_fasta = Channel.fromPath(params.race_linker, checkIfExists: true)
        } else {
            exit 1, "The oligo-dT 5'-RACE UMI library generation method requires a linker or Template Switch Oligo sequence, please provide it with the option '--race_linker'."
        }
        if (params.cprimers)  {
            ch_cprimers_fasta = Channel.fromPath(params.cprimers, checkIfExists: true)
        } else {
            exit 1, "The oligo-dT 5'-RACE UMI library generation method requires the C-region primer sequences, please provide a fasta file with the '--cprimers' option."
        }
        if (params.umi_length < 2)  {
            exit 1, "The oligo-dT 5'-RACE UMI 'dt_5p_race_umi' library generation method requires specifying the '--umi_length' to a value greater than 1."
        }
    } else if (params.library_generation_method == 'dt_5p_race') {
        if (params.vprimers) {
            exit 1, "The oligo-dT 5'-RACE library generation method does not accept V-region primers, please provide a linker with '--race_linker' instead or select another library method option."
        } else if (params.race_linker) {
            ch_vprimers_fasta = Channel.fromPath(params.race_linker, checkIfExists: true)
        } else {
            exit 1, "The oligo-dT 5'-RACE library generation method requires a linker or Template Switch Oligo sequence, please provide it with the option '--race_linker'."
        }
        if (params.cprimers)  {
            ch_cprimers_fasta = Channel.fromPath(params.cprimers, checkIfExists: true)
        } else {
            exit 1, "The oligo-dT 5'-RACE library generation method requires the C-region primer sequences, please provide a fasta file with the '--cprimers' option."
        }
        if (params.umi_length > 0)  {
            exit 1, "Please do not set a UMI length with the library preparation method oligo-dT 5'-RACE 'dt_5p_race'. Please specify instead a method that suports umi (e.g. 'dt_5p_race_umi')."
        } else {
            params.umi_length = 0
        }
    } else {
        exit 1, "The provided library generation method is not supported. Please check the docs for `--library_generation_method`."
    }

    // Validate UMI position
    if (params.index_file & params.umi_position == 'R2') {exit 1, "Please do not set `--umi_position` option if index file with UMIs is provided."}
    if (params.umi_length < 0) {exit 1, "Please provide the UMI barcode length in the option `--umi_length`. To run without UMIs, set umi_length to 0."}
    if (!params.index_file & params.umi_start != 0) {exit 1, "Setting a UMI start position is only allowed when providing the UMIs in a separate index read file. If so, please provide the `--index_file` flag as well."}


    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    ch_versions = Channel.empty()

    FASTQ_INPUT_CHECK(ch_input)

    ch_fastqc = FASTQ_INPUT_CHECK
        .out
        .reads
        .groupTuple(by: [0])
        .map{ it -> [ it[0], it[1].flatten() ] }

    ch_presto = ch_fastqc.map{ it -> it.flatten() }

    ch_versions = ch_versions.mix(FASTQ_INPUT_CHECK.out.versions)

    //
    // MODULE: FastQC
    //
    FASTQC ( ch_fastqc )

    // Channel for software versions
    ch_versions = ch_versions.mix(FASTQC.out.versions.ifEmpty(null))

    if (params.umi_length == 0) {
        //
        // SUBWORKFLOW: pRESTO without UMIs
        //
        PRESTO_SANS_UMI (
            ch_presto,
            ch_cprimers_fasta,
            ch_vprimers_fasta
        )
        ch_presto_fasta = PRESTO_SANS_UMI.out.fasta
        ch_presto_software = PRESTO_SANS_UMI.out.software
        ch_fastqc_postassembly = PRESTO_SANS_UMI.out.fastqc_postassembly_gz
        ch_presto_assemblepairs_logs = PRESTO_SANS_UMI.out.presto_assemblepairs_logs
        ch_presto_filterseq_logs = PRESTO_SANS_UMI.out.presto_filterseq_logs
        ch_presto_maskprimers_logs = PRESTO_SANS_UMI.out.presto_maskprimers_logs
        ch_presto_collapseseq_logs = PRESTO_SANS_UMI.out.presto_collapseseq_logs
        ch_presto_splitseq_logs = PRESTO_SANS_UMI.out.presto_splitseq_logs
        // These channels will be empty in the sans-UMI workflow
        ch_presto_pairseq_logs = Channel.empty()
        ch_presto_clustersets_logs = Channel.empty()
        ch_presto_buildconsensus_logs = Channel.empty()
        ch_presto_postconsensus_pairseq_logs = Channel.empty()
    } else {
        //
        // SUBWORKFLOW: pRESTO with UMIs
        //
        PRESTO_UMI (
            ch_presto,
            ch_cprimers_fasta,
            ch_vprimers_fasta
        )
        ch_presto_fasta = PRESTO_UMI.out.fasta
        ch_presto_software = PRESTO_UMI.out.software
        ch_fastqc_postassembly = PRESTO_UMI.out.fastqc_postassembly_gz
        ch_presto_filterseq_logs = PRESTO_UMI.out.presto_filterseq_logs
        ch_presto_maskprimers_logs = PRESTO_UMI.out.presto_maskprimers_logs
        ch_presto_pairseq_logs = PRESTO_UMI.out.presto_pairseq_logs
        ch_presto_clustersets_logs = PRESTO_UMI.out.presto_clustersets_logs
        ch_presto_buildconsensus_logs = PRESTO_UMI.out.presto_buildconsensus_logs
        ch_presto_postconsensus_pairseq_logs = PRESTO_UMI.out.presto_postconsensus_pairseq_logs
        ch_presto_assemblepairs_logs = PRESTO_UMI.out.presto_assemblepairs_logs
        ch_presto_collapseseq_logs = PRESTO_UMI.out.presto_collapseseq_logs
        ch_presto_splitseq_logs = PRESTO_UMI.out.presto_splitseq_logs
    }

    ch_versions = ch_versions.mix(ch_presto_software)

    emit:
    versions = ch_versions
    // assembled sequences in fasta format
    fasta = ch_presto_fasta
    // fastqc files for multiQC report
    fastqc_preassembly = FASTQC.out.zip
    fastqc_postassembly = ch_fastqc_postassembly
    // presto logs for html report
    presto_filterseq_logs = ch_presto_filterseq_logs
    presto_maskprimers_logs = ch_presto_maskprimers_logs
    presto_pairseq_logs = ch_presto_pairseq_logs
    presto_clustersets_logs = ch_presto_clustersets_logs
    presto_buildconsensus_logs = ch_presto_buildconsensus_logs
    presto_postconsensus_pairseq_logs = ch_presto_postconsensus_pairseq_logs
    presto_assemblepairs_logs = ch_presto_assemblepairs_logs
    presto_collapseseq_logs = ch_presto_collapseseq_logs
    presto_splitseq_logs = ch_presto_splitseq_logs
}



    // // Run Igblast for gene assignment
    // CHANGEO_ASSIGNGENES (
    //     ch_presto_fasta,
    //     ch_igblast.collect()
    // )
    // ch_versions = ch_versions.mix(CHANGEO_ASSIGNGENES.out.versions.ifEmpty(null))

    // // Make IgBlast results table
    // CHANGEO_MAKEDB (
    //     CHANGEO_ASSIGNGENES.out.fasta,
    //     CHANGEO_ASSIGNGENES.out.blast,
    //     ch_imgt.collect()
    // )
    // ch_versions = ch_versions.mix(CHANGEO_MAKEDB.out.versions.ifEmpty(null))

    // // Select only productive sequences.
    // CHANGEO_PARSEDB_SPLIT (
    //     CHANGEO_MAKEDB.out.tab
    // )
    // ch_versions = ch_versions.mix(CHANGEO_PARSEDB_SPLIT.out.versions.ifEmpty(null))

    // // Selecting IGH for ig loci, TR for tr loci.
    // CHANGEO_PARSEDB_SELECT(
    //     CHANGEO_PARSEDB_SPLIT.out.tab
    // )
    // ch_versions = ch_versions.mix(CHANGEO_PARSEDB_SELECT.out.versions.ifEmpty(null))

    // // Convert sequence table to fasta.
    // CHANGEO_CONVERTDB_FASTA (
    //     CHANGEO_PARSEDB_SELECT.out.tab
    // )
    // ch_versions = ch_versions.mix(CHANGEO_CONVERTDB_FASTA.out.versions.ifEmpty(null))

    // // Subworkflow: merge tables from the same patient
    // MERGE_TABLES_WF(
    //     CHANGEO_PARSEDB_SELECT.out.tab,
    //     ch_input.collect()
    // )

    // // Shazam clonal threshold
    // // Only if threshold is not manually set
    // if (!params.set_cluster_threshold){
    //     SHAZAM_THRESHOLD(
    //         MERGE_TABLES_WF.out.tab,
    //         ch_imgt.collect()
    //     )
    //     ch_tab_for_changeo_defineclones = SHAZAM_THRESHOLD.out.tab
    //     ch_threshold = SHAZAM_THRESHOLD.out.threshold
    //     ch_versions = ch_versions.mix(SHAZAM_THRESHOLD.out.versions.ifEmpty(null))
    // } else {
    //     ch_tab_for_changeo_defineclones = MERGE_TABLES_WF.out.tab
    //     ch_threshold = file('EMPTY')
    // }

    // // Define B-cell clones
    // CHANGEO_DEFINECLONES(
    //     ch_tab_for_changeo_defineclones,
    //     ch_threshold,
    // )
    // ch_versions = ch_versions.mix(CHANGEO_DEFINECLONES.out.versions.ifEmpty(null))

    // // Identify germline sequences
    // CHANGEO_CREATEGERMLINES(
    //     CHANGEO_DEFINECLONES.out.tab,
    //     ch_imgt.collect()
    // )
    // ch_versions = ch_versions.mix(CHANGEO_CREATEGERMLINES.out.versions.ifEmpty(null))

    // // Lineage reconstruction alakazam
    // if (!params.skip_lineage) {
    //     ALAKAZAM_LINEAGE(
    //         CHANGEO_CREATEGERMLINES.out.tab
    //     )
    //     ch_versions = ch_versions.mix(ALAKAZAM_LINEAGE.out.versions.ifEmpty(null))
    // }

    // ch_all_tabs_repertoire = CHANGEO_CREATEGERMLINES.out.tab
    //                                                 .map{ it -> [ it[1] ] }
    //                                                 .collect()

    // Process logs parsing: getting sequence numbers
    // PARSE_LOGS(
    //     ch_presto_filterseq_logs.collect(),
    //     ch_presto_maskprimers_logs.collect(),
    //     ch_presto_pairseq_logs.collect().ifEmpty([]),
    //     ch_presto_clustersets_logs.collect().ifEmpty([]),
    //     ch_presto_buildconsensus_logs.collect().ifEmpty([]),
    //     ch_presto_postconsensus_pairseq_logs.collect().ifEmpty([]),
    //     ch_presto_assemblepairs_logs.collect(),
    //     ch_presto_collapseseq_logs.collect(),
    //     ch_presto_splitseq_logs.collect(),
    //     //CHANGEO_MAKEDB.out.logs.collect(),
    //     ch_input
    // )
    // ch_versions = ch_versions.mix(PARSE_LOGS.out.versions.ifEmpty(null))

    // // Alakazam shazam repertoire comparison report
    // if (!params.skip_report){
    //     ALAKAZAM_SHAZAM_REPERTOIRES(
    //         ch_all_tabs_repertoire,
    //         PARSE_LOGS.out.logs.collect(),
    //         ch_report_rmd.collect(),
    //         ch_report_css.collect(),
    //         ch_report_logo.collect()
    //     )
    //     ch_versions = ch_versions.mix(ALAKAZAM_SHAZAM_REPERTOIRES.out.versions.ifEmpty(null))
    // }
