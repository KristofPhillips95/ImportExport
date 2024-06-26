#!/bin/bash -l


#SBATCH --cluster="genius"
#SBATCH --job-name="ScenarioLoopImExp"
#SBATCH --nodes="1"
#SBATCH --mail-user="kristof.phillips@kuleuven.be"
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --time="2:00:00"
#SBATCH --ntasks-per-node="36"
#SBATCH --account="lp_elect_gen_modeling"
#SBATCH --partition="batch"
      

cd $VSC_DATA/ImportExportCurves

echo "Starting runs"

julia FullScript_forPres.jl
