
# Handle cases where only sample_ncbi is defined in config.
if "prune_gtdb" not in config.keys():
    config["prune_gtdb"] = {"bac120": 0,
                            "ar53": 0,
                            "completeness": 0,
                            "contamination": 100,
                            "taxon": "",
                            "prune_method": "shortest"
                            }

if "sample_gtdb" not in config.keys():
    config["sample_gtdb"] = {"sampling_scheme": "",
                            "completeness": 0,
                            "contamination": 100,
                            "gtdb_species_representatives": False
                            }

rule prune_gtdb_phylogeny:
    input:
        phylogeny="gtdb_data/{domain}_r{version}.tree",
        metadata="gtdb_data/metadata_r{version}.wo_suppressed_records.tsv"
    output:
        phylogeny="prune_gtdb.{domain}_r{version}.nwk",
        metadata="prune_gtdb.{domain}_r{version}.metadata.tsv",
    params:
        taxa=lambda wildcards: config["prune_gtdb"]["{}".format(wildcards.domain)],
        completeness=config["prune_gtdb"]["completeness"],
        contamination=config["prune_gtdb"]["contamination"],
        prune_method=config["prune_gtdb"]["prune_method"],
        taxon=config["prune_gtdb"]["taxon"],
        seed=config["seed"]
    conda:
        "../envs/ete.yaml"
    script:
        "../scripts/prune_gtdb_phylogeny.py"

rule merge_prune_gtdb_output:
    input:
        bacteria_metadata = bac120_prune_input,
        archaea_metadata = ar53_prune_input
    output:
        metadata="prune_gtdb.metadata.tsv"
    conda:
        "../envs/base.yaml"
    script:
        "../scripts/merge_pruned_tables.py"


rule subsample_gtdb:
    """
    Use the metadata and taxonomy information to subsample the gtdb-data.
    """
    input:
        metadata=subsample_input,
        required_genomes="ncbi_data/required_genomes_checked.tsv" if config["required"] != "" else []
    output:
        "sample_gtdb.metadata.tsv"
    conda:
        "../envs/base.yaml"
    params:
        sampling_scheme=config["sample_gtdb"]["sampling_scheme"],
        completeness=config["sample_gtdb"]["completeness"],
        contamination=config["sample_gtdb"]["contamination"],
        gtdb_representative=config["sample_gtdb"]["gtdb_species_representatives"],
        seed=config["seed"],
    script:
        "../scripts/subsample_gtdb_taxonomy.py"

rule download_gtdb_summary:
    input:
        "{method}.metadata.tsv"
    output:
        temp("{method}.ncbi_datasets.tsv")
    conda:
        "../envs/ncbi-datasets.yaml"
    log:
        "logs/download_gtdb_summary.{method}.log" 
    shell:
        """
        awk -F'\\t'  '{{ print $1 }}' {input} | sed '1d' > accessions.tmp;
        datasets summary genome accession --inputfile accessions.tmp \
            --as-json-lines | sed 's/\\\\t//g' | \
        dataformat tsv genome > {output} 2> {log};
        rm accessions.tmp;
        """

rule filter_gtdb:
    """
    Merge the genome summary files into a single tsv table
    """
    input:
        "{method}.ncbi_datasets.tsv"
    output:
        "{method}.annotation_data.tsv"
    conda:
        "../envs/base.yaml"
    script:
        "../scripts/merge_datasets.py"
