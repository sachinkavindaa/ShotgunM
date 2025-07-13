#!/bin/bash -l
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=6
#SBATCH --mem=64gb
#SBATCH --licenses=common
#SBATCH --partition=guest,batch
#SBATCH --time=12:00:00
#SBATCH --job-name=run_QC_pipeline
#SBATCH --error=run_QC_pipeline.%J.stdout
#SBATCH --output=run_QC_pipeline.%J.stderr
#SBATCH --mail-user=echandrasekara2@unl.edu
#SBATCH --mail-type=ALL

module load sickle/1.33
module load bbmap/39.06
module load bowtie/2.5
module load fastqc/0.12
module load megahit/1.2
module load quast/5.0
module load bowtie/2.5
module load samtools/1.20
module load bbmap/39.06
module load prodigal/2.60
module load picard/2.22
module load biodata

mkdir MEGAHIT_assemblies
mkdir PRODIGAL_OUTPUTS
mkdir idxstat_files

#this is a QC and host decomtam pipeline for paired-end metagenomic reads!!
cd ShotgunM/Test

for dir in */; do
	cd $dir

	gunzip *.fq.gz # decompress .gz files (might not be essential as .gz files should also work)
	mv *"_1.fq" "forward.fq"	
	mv *"_2.fq" "reverse.fq"

        # remove adapters and other sequencing artifacts by matching sequences to those provided in the 'adapters.fa' file
	bbduk.sh in=forward.fq out=forward_adptrs_remvd.fq ref=/work/samodha/sachin/ShotgunM/adapters.fa ktrim=r k=23 mink=11 hdist=1 tpe tbo
	bbduk.sh in=reverse.fq out=reverse_adptrs_remvd.fq ref=/work/samodha/sachin/ShotgunM/adapters.fa ktrim=r k=23 mink=11 hdist=1 tpe tbo


	# removing reads matching PhiX
   	bbduk.sh in=forward_adptrs_remvd.fq out=forward_adptrs_remvd_phi_rem.fq k=31 ref=artifacts,phix ordered cardinality
        bbduk.sh in=reverse_adptrs_remvd.fq out=reverse_adptrs_remvd_phi_rem.fq k=31 ref=artifacts,phix ordered cardinality  


        # repair the forward reverse files so that both have the same number of reads (forward and reverse fastq files need to have same number of reads: otherwise, 'sickle' gives a warning)
	repair.sh in1=forward_adptrs_remvd_phi_rem.fq \
	in2=reverse_adptrs_remvd_phi_rem.fq \
	out1=forward_adptrs_remvd_phi_rem_fixed.fq \
	out2=reverse_adptrs_remvd_phi_rem_fixed.fq \
	outsingle=singletons.fq

	
	# quality trimming with 'Sickle'
	sickle pe -t sanger -f forward_adptrs_remvd_phi_rem_fixed.fq -r reverse_adptrs_remvd_phi_rem_fixed.fq -o forward_adptrs_remvd_phi_rem_fixed_trimmed.fq \
	-p reverse_adptrs_remvd_phi_rem_fixed_trimmed.fq -s trimmed_singles.fq -q 30 -l 50 # q - average quality within a window of Q30; -l minimum read length following quality trimming of 50 bp
                                                                            # the sliding window size for sickle is 0.1 x the length of a read

	# check to make sure that 'forward_adptrs_remvd_phi_rem_fixed_trimmed.fq' and 'reverse_adptrs_remvd_phi_rem_fixed_trimmed.fq' have  the same number of reads
	
	
	# remove host contamination
	mkdir bowtie2_host_cont_remv_output

	
	#for Human host
	bowtie2 -x /work/HCC/BCRF/Genomes/Homo_sapiens/UCSC/hg38/WholeGenomeFasta/genome.fa \
                -p 6 --very-sensitive \
                -1 forward_adptrs_remvd_phi_rem_fixed_trimmed.fq \
                -2 reverse_adptrs_remvd_phi_rem_fixed_trimmed.fq --un-conc bowtie2_host_cont_remv_output/nonhuman.fastq

        bowtie2 -x /work/HCC/BCRF/Genomes/Homo_sapiens/UCSC/hg38/WholeGenomeFasta/genome.fa\
                -p 6 --very-sensitive \
                -U trimmed_singles.fq --un bowtie2_host_cont_remv_output/nonhuman_single.fastq

	# renaming files
	mv "bowtie2_host_cont_remv_output/nonhuman.1.fastq" "bowtie2_host_cont_remv_output/$(basename "$(pwd)")_nonhuman.1.fastq"
	mv "bowtie2_host_cont_remv_output/nonhuman.2.fastq" "bowtie2_host_cont_remv_output/$(basename "$(pwd)")_nonhuman.2.fastq"
	mv "bowtie2_host_cont_remv_output/nonhuman_single.fastq" "bowtie2_host_cont_remv_output/$(basename "$(pwd)")_nonhuman_single.fastq"

	# check quality with FastQC
	fastqc bowtie2_host_cont_remv_output/*nonhuman.1.fastq
	fastqc bowtie2_host_cont_remv_output/*nonhuman.2.fastq
	fastqc bowtie2_host_cont_remv_output/*_nonhuman_single.fastq
	
	# copying files to MEGAHIT folder
	cp "bowtie2_host_cont_remv_output/"*".fastq" "/work/samodha/sachin/ShotgunM/MEGAHIT_assemblies"



	cd ../
done
