help_message = '
gwas_ldlink, v2020-06-26
This is a function for LDlink data.

Usage:
    Rscript postgwas-exe.r --ldlink down --base <base file> --out <out folder> --popul <CEU TSI FIN GBR IBS ...>
    Rscript postgwas-exe.r --ldlink filter --base <base file> <ldlink dir path> --out <out folder> --r2 0.6 --dprime 1
    Rscript postgwas-exe.r --ldlink filter --base <base file> --out <out folder> --r2 0.5
    Rscript postgwas-exe.r --ldlink bed --base <base file> --out <out folder>


Functions:
    down     This is a function for LDlink data download.
    filter   This is a function for LDlink data filter.
    bed      This is a function for generating two BED files (hg19 and hg38).

Global arguments:
    --base   <EFO0001359.tsv>
             One base TSV file is mendatory.
             A TSV file downloaded from GWAS catalog for "down" and "filter" functions.
             A TSV file processed from "filter" function for "bed" function.
    --out    <default: data>
             Out folder path is mendatory. Default is "data" folder.

Required arguments:
    --popul  <CEU TSI FIN GBR IBS ...>
             An argument for the "--ldlink ddown". One or more population option have to be included.
    --r2     An argument for the "--ldlink filter". Set a criteria for r2 over.
    --dprime An argument for the "--ldlink filter". Set a criteria for dprime over.
                1) r2 >0.6 and Dprime =1  <- The most stringent criteria.
                2) r2 >0.6               <- Usual choice to define LD association.
                3) Dprime =1
                4) r2 >0.6 or Dprime =1
                5) r2 >0.8
'

## Load global libraries ##
suppressMessages(library(dplyr))

## Functions Start ##
ldlink_bed = function(
    ldfl_path = NULL,   # LDlink filter result. Need to check removing NA value.
    out       = 'data', # Out folder path
    debug     = F
) {
    paste0('\n** Run function ldlink_bed... ') %>% cat
    ifelse(!dir.exists(out), dir.create(out),''); '\n' %>% cat # mkdir
    snps = read.delim(ldfl_path)
    dim(snps) %>% print

    # hg19: save as BED file
    snps_ = na.omit(snps[,c(1,6:8)])
    snps_hg19_length = snps_$hg19_end - snps_$hg19_start
    snp_bed_hg19_li = lapply(c(1:nrow(snps_)),function(i) {
        row = snps_[i,]
        if(snps_hg19_length[i]<0) {
            start = as.numeric(as.character(row$hg19_end))-1
            end   = row$hg19_start
        } else {
            start = as.numeric(as.character(row$hg19_start))-1
            end   = row$hg19_end
        }
        out = data.frame(
            chr   = row$hg19_chr,
            start = start,
            end   = end,
            rsid  = row$rsid
        )
        return(out)
    })
    snp_bed_hg19 = data.table::rbindlist(snp_bed_hg19_li) %>% unique
    if(debug) {
        hg19_snp_lenth = snp_bed_hg19$end - snp_bed_hg19$start
        table(hg19_snp_lenth) %>% print
    }
    f_name1 = paste0(out,'/gwas_hg19_biomart_',nrow(snp_bed_hg19),'.bed')
    write.table(snp_bed_hg19,f_name1,row.names=F,col.names=F,quote=F,sep='\t')
    paste0('Write file:\t',f_name1,'\n') %>% cat

    # hg38: save as BED file
    snps_ = na.omit(snps[,c(1,9:11)])
    snps_length = snps_$end - snps_$start
    snp_bed_hg38_li = lapply(c(1:nrow(snps_)),function(i) {
        row = snps_[i,]
        if(snps_length[i]<0) {
            start = as.numeric(as.character(row$end))-1
            end   = row$start
        } else {
            start = as.numeric(as.character(row$start))-1
            end   = row$end
        }
        out = data.frame(
            chr   = row$chr,
            start = start,
            end   = end,
            rsid  = row$rsid
        )
        return(out)
    })
    snp_bed_hg38 = data.table::rbindlist(snp_bed_hg38_li) %>% unique
    if(debug) {
        hg38_snp_lenth = snp_bed_hg38$end - snp_bed_hg38$start
        table(hg38_snp_lenth) %>% print
    }
    f_name2 = paste0(out,'/gwas_hg38_biomart_',nrow(snp_bed_hg38),'.bed')
    write.table(snp_bed_hg38,f_name2,row.names=F,col.names=F,quote=F,sep='\t')
    paste0('Write file:\t',f_name2,'\n') %>% cat
}

ldlink_filter = function(
    snp_path = NULL,   # GWAS file path
    ld_path  = NULL,   # LDlink download folder path
    out      = 'data', # Out folder path
    r2       = NULL,   # LDlink filter R2 criteria
    dprime   = NULL,   # LDlink filter Dprime criteria
    debug    = F
) {
    # Function specific library
    suppressMessages(library(biomaRt))  # download SNP coordiantes (hg19/hg38)
    #suppressMessages(library(circlize)) # download cytoband data (hg19)

    # Read downloaded files
    paste0('\n** Run function ldlink_filter...\n') %>% cat
    paste0('Read download files... ') %>% cat
    snpdf     = read.delim(snp_path,stringsAsFactors=F) %>% unique
    snpids    = snpdf$rsid %>% unique
    col_names = c('No','RS_Number','Coord','Alleles','MAF','Distance',
        'Dprime','R2','Correlated_Alleles','RegulomeDB','Function')
    ldlink    = paste0(ld_path,'/',snpids,'.txt')
    snptb     = data.frame(snpids=snpids, ldlink=ldlink)
    
    paste0(nrow(snptb),'\n') %>% cat
    ldlink_li = apply(snptb,1,function(row) {
        tb1 = try(
            read.table(as.character(row[2]),sep='\t',
                header=F,skip=1,stringsAsFactors=F,
                col.names=col_names) )
        if('try-error' %in% class(tb1)) {
            paste0('  [ERROR] ',row[1],'\n') %>% cat
            return(NULL)
        } else { # If no errors occurred,
            tb2 = data.frame(SNPid=rep(row[1],nrow(tb1)),tb1)
            return(tb2)
        }
    })
    ldlink_df = data.table::rbindlist(ldlink_li) %>% unique
    paste0('  Read LDlink results\t\t= ') %>% cat; dim(ldlink_df) %>% print
    
    # Filter the LDlink data
    if(!is.null(r2)) {
        r2 = as.numeric(r2)
        if(r2<1) {
            ldlink_df = subset(ldlink_df,R2>r2)
            paste0('    Filtering by "r2 > ',r2,'": ') %>% cat
        } else if(r2==1) {
            ldlink_df = subset(ldlink_df,R2==r2)
            paste0('    Filtering by "r2 = ',r2,'": ') %>% cat
        }
        dim(ldlink_df) %>% print
    } else paste0('    [Msg] No filter criteria for r2.\n') %>% cat

    if(!is.null(dprime)) {
        dprimt = as.numeric(dprime)
        if(dprime<1) {
            ldlink_df = subset(ldlink_df,Dprime<dprime)
            paste0('    Filtering by "Dprime > ',r2,'": ') %>% cat
        } else if(dprime==1) {
            ldlink_df = subset(ldlink_df,Dprime==dprime)
            paste0('    Filtering by "Dprime = ',dprime,'": ') %>% cat
        }
        dim(ldlink_df) %>% print
    } else paste0('    [Msg] No filter criteria for Dprime.\n') %>% cat

    ldlink_2 = data.frame(
        gwasSNPs = ldlink_df$SNPid,
        ldSNPs   = ldlink_df$RS_Number,
        ld_coord = ldlink_df$Coord
    ) %>% unique
    paste0('  Filtered data dimension \t= ') %>% cat; dim(ldlink_2) %>% print
    
    ldlink_ = ldlink_2[!ldlink_2$`ldSNPs` %in% c("."),] # Exclude no rsid elements
    ex = nrow(ldlink_2[ldlink_2$`ldSNPs` %in% c("."),])
    paste0('  Excluded no rsid elements\t= ') %>% cat; print(ex)
    
    # Save total LD SNPs
    if(!is.null(r2) & !is.null(dprime)) {
        ldlink_3 = ldlink_df
        ldlink_3$No = NULL
        colnames(ldlink_3)[1:3] = c('gwasSNPs','ldSNPs','ld_coord')

        # Save as CSV file
        f_name = paste0(out,'/gwas_ldlink_total.tsv')
        paste0('\n  Merged table\t\t= ') %>% cat; dim(ldlink_) %>% print
        write.table(ldlink_3,f_name,row.names=F,quote=F,sep='\t')
        paste0('  Write file: ',f_name,'\n') %>% cat
    }
    
    # Basic summary of LDlink results
    paste0('Basic summary of LDlink results:\n') %>% cat
    paste0('  SNP Tier 1\t\t\t= ',length(snpids),'\n') %>% cat
    snp_t2 = setdiff(ldlink_$ldSNPs,snpids) %>% unique
    paste0('  SNP Tier 2\t\t\t= ',length(snp_t2),'\n') %>% cat
    snp_cand = union(ldlink_$ldSNPs,snpids) %>% unique
    snps_ = data.frame(rsid=snp_cand)
    #write.table(snp_cand,'snp_cand.tsv',row.names=F,quote=F,sep='\t') # For debug
    paste0('  SNP candidates\t\t= ',length(snp_cand),'\n') %>% cat

    # Prepare SNP source annotation table
    snp_src1 = data.frame(
        rsid   = snpids,
        source = rep('GWAS',length(snpids))
    )
    snp_src2 = data.frame(
        rsid   = snp_t2,
        source = rep('Ldlink',length(snp_t2))
    )
    snp_src = rbind(snp_src1,snp_src2)
    paste0('  SNP source annotation table\t= ') %>% cat; dim(snp_src) %>% print

    # Add LD block annotation
    paste0('Add annotations:\n') %>% cat
    paste0('  LD block annotation... ') %>% cat
    ldlink_2 = ldlink_
    colnames(ldlink_2)[2] = 'rsid'
    ldlink_3 = merge(snps_,ldlink_2,by='rsid',all.x=T)

    ## Make group1
    gwas_snps = ldlink_3$gwasSNPs %>% as.character %>% na.omit %>% unique
    n = length(gwas_snps)
    group1 = list()
    for(i in 1:n) {
        ldsnps = subset(ldlink_3,gwasSNPs==gwas_snps[i])$rsid %>% as.character
        block  = c(gwas_snps[i],ldsnps) %>% unique
        if(i==1) group1[[1]] = block
        m = length(group1)
        for(j in 1:m) {
            inter_N = intersect(group1[[j]],block) %>% length
            if(inter_N>0) {
                group1[[j]] = union(group1[[j]],block)
                break
            } else if(inter_N==0 & j==m) group1[[j+1]] = block
        }
    }

    ## Check duplicate in group1 to generate group2
    n = length(group1)
    group2 = list()
    for(i in 1:n) {
        if(i==1) group2[[1]] = group1[[i]]
        m = length(group2)
        for(j in 1:m) {
            inter_N = intersect(group1[[i]],group2[[j]]) %>% length
            if(inter_N>0) {
                group2[[j]] = union(group1[[i]],group2[[j]])
                break
            } else if(inter_N==0 & j==m) group2[[j+1]] = group1[[i]]
        }
    }
    ld_bid = formatC(c(1:length(group2)),width=3,flag='0') %>% as.character # "001"
    names(group2) = paste0('ld_block',ld_bid)
    ldblock = stack(group2) %>% unique
    colnames(ldblock) = c('rsid','ld_blocks')
    group2 %>% length %>% print

    # Search biomart hg19 to get coordinates
    paste0('Search biomart for SNP coordinates:\n') %>% cat
    paste0('  Query SNPs\t\t= ') %>% cat; length(snp_cand) %>% print
    paste0('  Hg19 result table\t= ') %>% cat
    hg19_snp = useMart(biomart="ENSEMBL_MART_SNP",host="grch37.ensembl.org",
                       dataset='hsapiens_snp',path='/biomart/martservice')
    snp_attr1 = c("refsnp_id","chr_name","chrom_start","chrom_end")
    snps_hg19_bio1 = getBM(
        attributes = snp_attr1,
        filters    = "snp_filter",
        values     = snp_cand,
        mart       = hg19_snp) %>% unique
    snps_merge = merge(snps_,snps_hg19_bio1,
                       by.x='rsid',by.y='refsnp_id',all.x=T)
    which_na = is.na(snps_merge$chr_name) %>% which

    if(length(which_na)>0) {
        snps_na = snps_merge[which_na,1]
        snp_attr2 = c("refsnp_id",'synonym_name',"chr_name","chrom_start","chrom_end")
        snps_hg19_bio2 = getBM(
            attributes = snp_attr2,
            filters    = "snp_synonym_filter",
            values     = snps_na,
            mart       = hg19_snp) %>% unique
        snps_hg19_bio2 = snps_hg19_bio2[,c(2:5)]
        colnames(snps_hg19_bio2)[1] = "refsnp_id"
        snps_hg19_bio = rbind(snps_hg19_bio1,snps_hg19_bio2) %>% unique
    } else snps_hg19_bio = snps_hg19_bio1
    colnames(snps_hg19_bio) = c('rsid','hg19_chr','hg19_start','hg19_end')
    snps_hg19_bio_ = subset(snps_hg19_bio,hg19_chr %in% c(1:22,'X','Y'))
    snps_hg19_bio_[,2] = paste0('chr',snps_hg19_bio_[,2])
    #snps_hg19_bio_[,3] = as.numeric(as.character(snps_hg19_bio_[,3]))-1
    dim(snps_hg19_bio_) %>% print

    # Search biomart hg38 to get coordinates
    paste0('  Hg38 result table\t= ') %>% cat
    hg38_snp = useMart(biomart="ENSEMBL_MART_SNP",dataset="hsapiens_snp")
    snps_bio1 = getBM(
        attributes = snp_attr1,
        filters    = "snp_filter",
        values     = snp_cand,
        mart       = hg38_snp) %>% unique
    snps_merge = merge(snps_,snps_bio1,
                       by.x='rsid',by.y='refsnp_id',all.x=T)
    which_na = is.na(snps_merge$chr_name) %>% which

    if(length(which_na)>0) {
        snps_na = snps_merge[which_na,1]
        snps_bio2 = getBM(
            attributes = snp_attr2,
            filters    = "snp_synonym_filter",
            values     = snps_na,
            mart       = hg38_snp) %>% unique
        snps_bio2 = snps_bio2[,c(2:5)]
        colnames(snps_bio2)[1] = "refsnp_id"
        snps_bio = rbind(snps_bio1,snps_bio2) %>% unique
    } else snps_bio = snps_bio1
    colnames(snps_bio) = c('rsid','chr','start','end')
    snps_bio_       = subset(snps_bio,chr %in% c(1:22,'X','Y'))
    snps_bio_[,2]   = paste0('chr',snps_bio_[,2])
    #snps_bio_[,3]   = as.numeric(as.character(snps_bio_[,3]))-1
    dim(snps_bio_) %>% print

    # Merge the biomart result with the GWAS SNP list
    merge_multi = function(x,y) { merge(x,y,by='rsid',all.x=T) }
    #snps_merge = merge(snps_,snps_bio_,by='rsid',all.x=TRUE)
    colnames(ldlink_)[2] = 'rsid'
    snps_li = list(
        snps_,
        ldlink_[,2:3],
        ldblock,
        snp_src,
        snps_hg19_bio_,
        snps_bio_
    )
    snps_merge1 = Reduce(merge_multi,snps_li) %>% unique

    # Add Cytoband annotation (hg19)
    coord    = snps_merge1$ld_coord
    hg19_chr = snps_merge1$hg19_chr
    hg19_end = snps_merge1$hg19_end

    ## Download cytoband data from UCSC
    paste0('  Cytoband annotation... ') %>% cat
    cyto     = circlize::read.cytoband(species = 'hg19')$df
    colnames(cyto) = c('chr','start','end','cytoband','tag')

    ## Split SNP coord to CHR and POS
    coord_li = lapply(coord,function(c) {
        split = strsplit(c %>% as.character,'\\:') %>% unlist
        data.frame(
            chr = split[1],
            pos = split[2] %>% as.numeric
        )
    })
    coord_df = data.table::rbindlist(coord_li)
    
    ## Extract and merge cytoband data
    n = nrow(coord_df)
    cytoband = lapply(c(1:n),function(i) {
        CHR = coord_df[i,1] %>% unlist
        POS = coord_df[i,2] %>% unlist
        cyto_sub = subset(cyto, chr==CHR & start<=POS & end>=POS)$cytoband
        if(length(cyto_sub)==0) {
            CHR = hg19_chr[i]
            POS = hg19_end[i]
            cyto_sub = subset(cyto, chr==CHR & start<=POS & end>=POS)$cytoband
        }
        chr = strsplit(CHR %>% as.character,'chr') %>% unlist
        cytoband = paste0(chr[2],cyto_sub)
        return(cytoband)
    }) %>% unlist
    paste0(length(cytoband),'.. ') %>% cat
    snps_merge = data.frame(snps_merge1[,1:4],cytoband,snps_merge1[,5:10])
    paste0('done\n') %>% cat

    # Write a TSV file
    ifelse(!dir.exists(out), dir.create(out),''); '\n' %>% cat # mkdir
    f_name1 = paste0(out,'/gwas_biomart.tsv')
    paste0('  Merged table\t\t= ') %>% cat; dim(snps_merge) %>% print
    write.table(snps_merge,f_name1,row.names=F,quote=F,sep='\t')
    paste0('Write file: ',f_name1,'\n') %>% cat
}

ldlink_down = function(
    snp_path = NULL,   # gwassnp_summ: 'filter' result file path
    out      = 'data', # out folder path
    popul    = NULL,   # population filter option for LDlink
    debug    = F
) {
    # Function specific library
    suppressMessages(library(LDlinkR))

    # Download from LDlink
    paste0('\n** Run function ldlink_down... ') %>% cat
    snps = read.delim(snp_path,stringsAsFactors=F)
    rsid = snps$rsid %>% unique
    paste0(rsid%>%length,'.. ') %>% cat

    ifelse(!dir.exists(out), dir.create(out),''); '\n' %>% cat # mkdir
    token = '669e9dc0b428' # Seungsoo Kim's personal token
    LDproxy_batch(snp=rsid, pop=popul, r2d='d', token=token) #append=T
    paste0('done\n') %>% cat
    
    # Rename downloaded file
    f_name  = paste0(rsid,'.txt')
    f_name1 = paste0(out,'/',f_name)
    file.rename(f_name,f_name1)
    paste0('  Files are moved to target folder:\t',out,'\n') %>% cat
}

gwas_ldlink = function(
    args = NULL
) {
    if(length(args$help)>0) {   help    = args$help
    } else                      help    = FALSE
    if(help) {                  cat(help_message); quit() }
    
    if(length(args$base)>0)     b_path  = args$base
    if(length(args$out)>0)      out     = args$out
    if(length(args$debug)>0) {  debug   = args$debug
    } else                      debug   = FALSE
    
    if(length(args$popul)>0)    popul   = args$popul
    if(length(args$r2)>0) {     r2      = args$r2
    } else                      r2      = NULL
    if(length(args$dprime)>0) { dprime  = args$dprime
    } else                      dprime  = NULL
    
    source('src/pdtime.r'); t0=Sys.time()
    if(args$ldlink == 'down') {
        ldlink_down(b_path,out,popul,debug)
    } else if(args$ldlink == 'filter') {
        ldlink_filter(b_path[1],b_path[2],out,r2,dprime,debug)
    } else if(args$ldlink == 'bed') {
        ldlink_bed(b_path,out,debug)
    } else {
        paste0('[Error] There is no such function in gwas_ldlink: ',
            paste0(args$ldlink,collapse=', '),'\n') %>% cat
    }
    paste0(pdtime(t0,1),'\n') %>% cat
}