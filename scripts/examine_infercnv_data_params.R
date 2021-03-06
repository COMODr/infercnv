#!/usr/bin/env Rscript

args<-commandArgs(TRUE)

if (length(args) == 0) {
    stop("Error, require params: infercnv.obj");
}

infercnv_obj_file = args[1]

infercnv_obj = readRDS(infercnv_obj_file)


library(edgeR)
library(fitdistrplus)
library(infercnv)
library(Matrix)

# borrowing some code from splatter

get_parameters <- function(group_name, expr.matrix) {

    message(sprintf("getting params for: %s", group_name))
    params = list()
    params[['group_name']] = group_name
    
    # estimate gamma for  genes
    lib.sizes <- colSums(expr.matrix)
    lib.med <- median(lib.sizes)
    norm.counts <- t(t(expr.matrix) / lib.sizes * lib.med)
    norm.counts <- norm.counts[rowSums(norm.counts > 0) > 1, ]

    ## note, fitting the gamma is done differently in splatter... using method = "mge", gof = "CvM", and first winsorizing the data at q=0.1
    means <- rowMeans(norm.counts)
    means.fit <- fitdistrplus::fitdist(means, "gamma", method = "mme")
    mean.shape = unname(means.fit$estimate["shape"])
    mean.rate = unname(means.fit$estimate["rate"])
    
    params[[ 'gamma.mean.shape' ]] = mean.shape
    params[[ 'gamma.mean.rate' ]] = mean.rate
    
    
    # estimate dropout params
    mean_vs_p0_table = infercnv:::.get_mean_vs_p0_from_matrix(expr.matrix)
    logistic_params = infercnv:::.get_logistic_params(mean_vs_p0_table)

    params[['dropout.logistic.midpt']] = logistic_params$midpt
    params[['dropout.logistic.slope']] = logistic_params$slope
        
    
    # estimate common dispersion
    design <- matrix(1, ncol(expr.matrix), 1)
    disps <- edgeR::estimateDisp(expr.matrix, design = design)

    params[[ 'common.dispersion' ]] = disps$common.dispersion
    

    return(params)

}



# examine each group
all_groups = c(infercnv_obj@observation_grouped_cell_indices,  infercnv_obj@reference_grouped_cell_indices)
all_groups[['combined_normal']] <- unlist(infercnv_obj@reference_grouped_cell_indices)

for (group in names(all_groups)) {

    group_idxs = all_groups[[ group ]]
    expr.data = infercnv_obj@expr.data[,  group_idxs]

    params = get_parameters(group, expr.data)
    params = t(as.data.frame(params))
    
    print(params)
    
}

