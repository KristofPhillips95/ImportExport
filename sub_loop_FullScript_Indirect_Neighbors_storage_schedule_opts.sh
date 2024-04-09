#!/bin/bash -l

#SBATCH --cluster="genius"
#SBATCH --job-name="ImpExpInDirStor"
#SBATCH --nodes="1"
#SBATCH --mail-user="kristof.phillips@kuleuven.be"
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --time="72:00:00"
#SBATCH --ntasks-per-node="36"
#SBATCH --account="lp_elect_gen_modeling"
#SBATCH --partition="batch"
      

cd $VSC_DATA/ImportExportCurves

echo "Starting runs"

julia FullScript_Indirect_Neighbors_storage_schedule_opts.jl