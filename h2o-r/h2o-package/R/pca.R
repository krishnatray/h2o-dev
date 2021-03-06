# ----------------------- Principal Components Analysis ----------------------------- #
h2o.prcomp <- function(data, tol=0, cols = "", max_pc = 5000, key = "", standardize=TRUE, retx=FALSE) {
  args <- .verify_datacols(data, cols)

  if(!is.character(key)) stop("key must be of class character")
  if(nchar(key) > 0 && regexpr("^[a-zA-Z_][a-zA-Z0-9_.]*$", key)[1] == -1)
    stop("key must match the regular expression '^[a-zA-Z_][a-zA-Z0-9_.]*$'")
  if(!is.numeric(tol)) stop('tol must be numeric')
  if(!is.logical(standardize)) stop('standardize must be TRUE or FALSE')
  if(!is.logical(retx)) stop('retx must be TRUE or FALSE')
  if(!is.numeric(max_pc)) stop('max_pc must be a numeric')

  res = .h2o.__remoteSend(data@h2o, .h2o.__PAGE_PCA, source=data@key, destination_key=key, ignored_cols = args$cols_ignore, tolerance=tol, standardize=as.numeric(standardize))
  .h2o.__waitOnJob(data@h2o, res$job_key)
  destKey = res$destination_key
  # while(!.h2o.__isDone(data@h2o, "PCA", res)) { Sys.sleep(1) }
  res2 = .h2o.__remoteSend(data@h2o, .h2o.__PAGE_PCAModelView, '_modelKey'=destKey)
  res2 = res2$pca_model

  result = list()
  result$params$names = res2$'_names'
  result$params$x = res2$namesExp
  result$num_pc = res2$num_pc
  result$standardized = standardize
  result$sdev = res2$sdev
  nfeat = length(res2$eigVec[[1]])
  if(max_pc > nfeat) max_pc = nfeat
  temp = t(matrix(unlist(res2$eigVec), nrow = nfeat))[,1:max_pc]
  temp = as.data.frame(temp)
  rownames(temp) = res2$namesExp #'_names'
  colnames(temp) = paste("PC", seq(0, ncol(temp)-1), sep="")
  result$rotation = temp

  if(retx) result$x = h2o.predict(new("H2OPCAModel", key=destKey, data=data, model=result), num_pc = max_pc)
  new("H2OPCAModel", key=destKey, data=data, model=result)
}


h2o.pcr <- function(x, y, data, key = "", ncomp, family, nfolds = 10, alpha = 0.5, lambda = 1.0e-5, epsilon = 1.0e-5, tweedie.p = ifelse(family=="tweedie", 0, as.numeric(NA))) {
  args <- .verify_dataxy(data, x, y)

  if(!is.character(key)) stop("key must be of class character")
  if(nchar(key) > 0 && regexpr("^[a-zA-Z_][a-zA-Z0-9_.]*$", key)[1] == -1)
    stop("key must match the regular expression '^[a-zA-Z_][a-zA-Z0-9_.]*$'")
  if( !is.numeric(nfolds) ) stop('nfolds must be numeric')
  if( nfolds < 0 ) stop('nfolds must be >= 0')
  if( !is.numeric(alpha) ) stop('alpha must be numeric')
  if( alpha < 0 ) stop('alpha must be >= 0')
  if( !is.numeric(lambda) ) stop('lambda must be numeric')
  if( lambda < 0 ) stop('lambda must be >= 0')

  cc = colnames(data)
  y <- args$y
  if( ncomp < 1 || ncomp > length(cc) ) stop("Number of components must be between 1 and ", ncol(data))

  x_ignore <- args$x_ignore
  x_ignore <- ifelse( x_ignore=='', y, c(x_ignore,y) )
  myModel <- .h2o.prcomp.internal(data=data, x_ignore=x_ignore, dest="", max_pc=ncomp, tol=0, standardize=TRUE)
  myScore <- h2o.predict(myModel, num_pc = ncomp)

  myScore[,ncomp+1] = data[,args$y_i]    # Bind response to frame of principal components
  myGLMData = .h2o.exec2(myScore@key, h2o = data@h2o, myScore@key)
  h2o.glm(x = 1:ncomp,
          y = ncomp+1,
          data = myGLMData,
          key = key,
          family = family,
          nfolds = nfolds,
          alpha = alpha,
          lambda = lambda,
          epsilon = epsilon,
          standardize = FALSE,
          tweedie.p = tweedie.p)
}

.h2o.prcomp.internal <- function(data, x_ignore, dest, max_pc=5000, tol=0, standardize=TRUE) {
  res = .h2o.__remoteSend(data@h2o, .h2o.__PAGE_PCA, source=data@key, ignored_cols_by_name=x_ignore, destination_key=dest, max_pc=max_pc, tolerance=tol, standardize=as.numeric(standardize))
  .h2o.__waitOnJob(data@h2o, res$job_key)
  # while(!.h2o.__isDone(data@h2o, "PCA", res)) { Sys.sleep(1) }
  destKey = res$destination_key
  res2 = .h2o.__remoteSend(data@h2o, .h2o.__PAGE_PCAModelView, '_modelKey'=destKey)
  res2 = res2$pca_model

  result = list()
  result$params$x = res2$'_names'
  result$num_pc = res2$num_pc
  result$standardized = standardize
  result$sdev = res2$sdev
  nfeat = length(res2$eigVec[[1]])
  temp = t(matrix(unlist(res2$eigVec), nrow = nfeat))
  rownames(temp) = res2$'namesExp'
  colnames(temp) = paste("PC", seq(1, ncol(temp)), sep="")
  result$rotation = temp
  new("H2OPCAModel", key=destKey, data=data, model=result)
}

.get.pca.results <- function(data, json, destKey, params) {
  json$params <- params
  json$rotation <- t(matrix(unlist(json$eigVec), nrow = length(json$eigVec[[1]])))
  rownames(json$rotation) <- json$'namesExp'
  colnames(json$rotation) <- paste("PC", seq(1, ncol(json$rotation)), sep = "")
  new("H2OPCAModel", key = destKey, data = data, model = json)
}
