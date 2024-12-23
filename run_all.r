#!/usr/bin/env Rscript

# launch script to run all inversion parts in order
# author: Lewis Kunik

# start the clock to keep track of how long it takes for the script to run
ptm1_all <- proc.time()


# ~~~~~~~~~~~ Load configuration file ~~~~~~~~~#

source("config.r")

# Copy the config files to the run directory

file.copy("config.r", paste0(run_path, "config.r"), overwrite = TRUE)
config_content <- readLines(paste0(run_path, "config.r"))
config_content <- gsub("run_path <- \".*\"|run_path <- '.*'", "run_path <- './'", config_content)
writeLines(config_content, paste0(run_path, "config.r"))

file.copy("config_R_uncert.r", paste0(run_path, "config_R_uncert.r"), overwrite = TRUE)


# ~~~~~~~~~~~ Create directory structure ~~~~~~~~~#

if(!dir.exists(out_path))
    dir.create(out_path)

if(!dir.exists(H_path))
    dir.create(H_path)

if(!is.na(lonlat_outer_file) & !dir.exists(H_outer_path))
    dir.create(H_outer_path)

if(!dir.exists(HQ_path))
    dir.create(HQ_path)


# ~~~~~~~~~~~ Clear all existing data files before proceeding ~~~~~~~~~#

# get all files in the out directory
out_files <- paste0(out_path, list.files(out_path))

if (clear_H) {
    # H files
    if (length(list.files(H_path)) > 0) {
        out_files <- c(out_files, paste0(H_path, list.files(H_path)))
    }

    # H files (outer domain)
    if (!is.na(lonlat_outer_file) & length(list.files(H_outer_path)) > 0) {
        out_files <- c(out_files, paste0(H_outer_path, list.files(H_outer_path)))
    }
}

# HQ files
if (length(list.files(HQ_path)) > 0) {
    out_files <- c(out_files, paste0(HQ_path, list.files(HQ_path)))
}

# determine which of these files exist (redundant but good)
iFiles <- which(file.exists(out_files))

# remove existing files to clean the directory
invisible(sapply(out_files[iFiles], FUN = function(x) system(paste("rm", x))))


# ~~~~~~~~~~~~~~~~~ run scripts in order ~~~~~~~~~~~~~~~~~#

# 1. make receptor list (list of all footprint files used for observations)
print("~~~~~~~~~~~~~~~~~~~~~~~~")
print("running make_receptors.r")
print("~~~~~~~~~~~~~~~~~~~~~~~~")
source(paste0(src_path, "make_receptors.r"))

# 2. make sprior (prior emissions vector)
print("~~~~~~~~~~~~~~~~~~~~~~~~")
print("running make_sprior.r")
print("~~~~~~~~~~~~~~~~~~~~~~~~")
source(paste0(src_path, "make_sprior.r"))

if (include_outer) {
    # 3. make outer (outer-domain emissions vector)
    print("~~~~~~~~~~~~~~~~~~~~~~~~")
    print("running make_outer.r")
    print("~~~~~~~~~~~~~~~~~~~~~~~~")
    source(paste0(src_path, "make_outer.r"))
}

# 4. make sigma (prior uncertainty vector)
print("~~~~~~~~~~~~~~~~~~~~~~~~")
print("running make_sigma.r")
print("~~~~~~~~~~~~~~~~~~~~~~~~")
source(paste0(src_path, "make_sigma.r"))

if (include_bio) {
    # 5. make sbio - biogenic flux vector
    print("~~~~~~~~~~~~~~~~~~~~~~~~")
    print("running make_sbio.r")
    print("~~~~~~~~~~~~~~~~~~~~~~~~")
    source(paste0(src_path, "make_sbio.r"))
}

if (clear_H) {
    # 6. make H (footprint matrices)
    print("~~~~~~~~~~~~~~~~~~~~~~~~")
    print("running Hsplit.r")
    print("~~~~~~~~~~~~~~~~~~~~~~~~")
    source(paste0(src_path, "Hsplit.r"))
}

if (include_outer | include_bio) {
    # 7. derive biogenic and outer-domain additions to bkgd
    print("~~~~~~~~~~~~~~~~~~~~~~~~")
    print("running make_Hs_bkgd.r")
    print("~~~~~~~~~~~~~~~~~~~~~~~~")
    source(paste0(src_path, "make_Hs_bkgd.r"))
}

# 8. make spatial covariance matrix
print("~~~~~~~~~~~~~~~~~~~~~~~~")
print("running make_sp_cov.r")
print("~~~~~~~~~~~~~~~~~~~~~~~~")
source(paste0(src_path, "make_sp_cov.r"))

# 9. make temporal covariance matrix
print("~~~~~~~~~~~~~~~~~~~~~~~~")
print("running make_tmp_cov.r")
print("~~~~~~~~~~~~~~~~~~~~~~~~")
source(paste0(src_path, "make_tmp_cov.r"))

# 10. make HQ
print("~~~~~~~~~~~~~~~~~~~~~~~~")
print("running make_HQ.r")
print("~~~~~~~~~~~~~~~~~~~~~~~~")
source(paste0(src_path, "make_HQ.r"))

# 11. make bkgd
print("~~~~~~~~~~~~~~~~~~~~~~~~")
print("running make_bg.r")
print("~~~~~~~~~~~~~~~~~~~~~~~~")
source(paste0(src_path, "make_bg.r"))

# 12. make z (anthropogenic enhancement values)
print("~~~~~~~~~~~~~~~~~~~~~~~~")
print("running make_z.r")
print("~~~~~~~~~~~~~~~~~~~~~~~~")
source(paste0(src_path, "make_z.r"))

# 13. make R (model data mismatch)
print("~~~~~~~~~~~~~~~~~~~~~~~~")
print("running make_R.r")
print("~~~~~~~~~~~~~~~~~~~~~~~~")
source(paste0(src_path, "make_R.r"))

# 14. make z - Hsp
print("~~~~~~~~~~~~~~~~~~~~~~~~")
print("running make_zHsp.r")
print("~~~~~~~~~~~~~~~~~~~~~~~~")
source(paste0(src_path, "make_zHsp.r"))

# 15. make s_hat (optimized emissions vector)
print("~~~~~~~~~~~~~~~~~~~~~~~~")
print("running inversion.r")
print("~~~~~~~~~~~~~~~~~~~~~~~~")
source(paste0(src_path, "inversion.r"))

# 16. make_Vshat (posterior uncertainty - technically makes Vshat-bar, which is
# the grid-scale aggregated uncertainty)
print("~~~~~~~~~~~~~~~~~~~~~~~~")
print("running make_Vshat.r")
print("~~~~~~~~~~~~~~~~~~~~~~~~")
source(paste0(src_path, "make_Vshat.r"))

# 17. convert posterior emissions/uncertainty into netcdf format for interpreting results
print("~~~~~~~~~~~~~~~~~~~~~~~~")
print("saving results to netcdf")
print("~~~~~~~~~~~~~~~~~~~~~~~~")
source(paste0(src_path, "post_proc.r"))

if (compute_chi_sq) {
    # 18. calculate Chi-squared
    print("~~~~~~~~~~~~~~~~~~~~~~~~")
    print("running chi_sq.r")
    print("~~~~~~~~~~~~~~~~~~~~~~~~")
    source(paste0(src_path, "chi_sq.r"))
}


# ~~~~~~~~~~~~~~~~ get elapsed time data ~~~~~~~~~~~~~~~~#

print("~~~~~~~~~~~~~~~~~~~~~~~~")
print("~~~~~~~~~~~~~~~~~~~~~~~~")
print("~~~~~~~~~~~~~~~~~~~~~~~~")
ptm2_all <- proc.time()
elapsed_seconds <- as.numeric(ptm2_all["elapsed"] - ptm1_all["elapsed"])
e_mins <- round(elapsed_seconds/60)
e_secs <- round(elapsed_seconds%%60, digits = 1)
print(paste0("elapsed time: ", e_mins, " minutes, ", e_secs, " seconds"))
