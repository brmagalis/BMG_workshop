print("Loading required packages...")

.packages = c("tidyverse", "ape", "treeio", "ggtree",  "ggnewscale", "RColorBrewer", "ggtreeExtra")

if (!require("BiocManager", quietly = TRUE))
  install.packages("BiocManager")

.missing = .packages[!sapply(.packages, requireNamespace, quietly = TRUE)]

if (length(.missing) > 0) {
  BiocManager::install(.missing)
}

lapply(.packages, require, character.only = TRUE)

print("Reading in necessary files...")

tree = read.beast("tardis.treefile")@phylo

if(length(tree)==0) {
  print("No tree file found. Make sure this script is run inside its original directory and that the 'step1' folder has been de-compressed.")
}

aln_file=list.files(pattern="tardis_corrected.aln")

if(length(aln_file)==0) {
  aln=read.dna("../bake/tardis_corrected.aln", format="fasta", as.character=TRUE)
}

mut_501_df = data.frame(taxon = rownames(aln),
                        N501Y=do.call(rbind, lapply(1:nrow(aln), function(x) {
                          if(aln[x,23063]=="t") {
                            return("N501Y")
                          } else {
                            if (aln[x,23063]=="a") {
                              return("")
                            } else {
                            return("Unknown")
                            }
                          }})))

metadata = read.csv("tardis_metadata.csv") %>%
  filter(taxon %in% tree$tip.label) %>%
  select(taxon, scorpio_call) %>%
  mutate(lineage = ifelse(scorpio_call=="", "Other",
                               scorpio_call),
         origin = gsub(".+\\|([A-Za-z]+)$", "\\1", taxon)) %>%
  mutate(origin = ifelse(grepl("/FL", taxon), "Local", origin)) %>%
  mutate(origin=factor(origin),
         lineage=factor(lineage)) %>%
  left_join(mut_501_df) 

rownames(metadata) = metadata$taxon
palette_colors <- brewer.pal(n = 7, name = "Set2")

palette_colors[which(levels(metadata$origin) == "Local")] <- "darkblue"  # bright red


print("Generating plot for full tree...")

## Set colors
variant_levels <- levels(factor(metadata$lineage))

variant_colors <- setNames(
  RColorBrewer::brewer.pal(
    max(3, length(variant_levels)),
    "Set3"
  )[seq_along(variant_levels)],
  variant_levels
)

origin_levels <- levels(factor(metadata$origin))

# Ensure palette_colors is named
origin_colors <- setNames(
  palette_colors[seq_along(origin_levels)],
  origin_levels
)

n501y_levels <- levels(factor(metadata$N501Y))

n501y_colors <- setNames(
  c("white", "black", "grey")[seq_along(n501y_levels)],
  n501y_levels
)

# Now plot
plot_tree_meta = function(tree) {
  p=ggtree(tree, color="darkgrey") %<+% metadata 
  #------------------------------------------------------------
  # Variant
  #------------------------------------------------------------
  
  p_variant = p +
    geom_fruit(
      geom=geom_tile,
      mapping=aes(fill=lineage),
      width=0.06*max(p$data$x),
      show.legend=T) +
    scale_fill_manual(values=variant_colors, name="Variant", drop=FALSE) +
    annotate( "text",
              x = 0.03*max(p$data$x)+max(p$data$x),  # horizontal position in fruit panel
              y = 0.015*length(tree$tip.label)+length(tree$tip.label),  # just above top tip
              label = "Variant",
              fontface = "bold",
              size = 3,
              angle=45, hjust=-0.1)
  #------------------------------------------------------------
  # Origin
  #------------------------------------------------------------

  p_origin = p_variant + new_scale_fill() +
    geom_fruit(
      geom=geom_tile,
      mapping=aes(fill=origin),
      width=0.06*max(p$data$x),
      offset=0.03*3) +
    scale_fill_manual(values=palette_colors, name="Origin", drop=FALSE) +
    annotate( "text",
              x = 4*0.03*max(p$data$x)+max(p$data$x),  # horizontal position in fruit panel
              y = 0.015*length(tree$tip.label)+length(tree$tip.label),  # just above top tip
              label = "Origin",
              fontface = "bold",
              size = 3,
              angle=45, hjust=-0.1)
    #------------------------------------------------------------
    # N501Y
    #------------------------------------------------------------
    
  
  pn501y = p_origin + new_scale_fill() +
    geom_fruit(
      geom=geom_tile,
      mapping=aes(fill=N501Y),
      width=0.06*max(p$data$x),
      offset=0.03*3) +
    scale_fill_manual(values=n501y_colors, name="N501Y", drop=FALSE) +
    annotate( "text",
                x = 7*0.03*max(p$data$x)+max(p$data$x),  # horizontal position in fruit panel
                y = 0.015*length(tree$tip.label)+length(tree$tip.label),  # just above top tip
                label = "N501Y",
              fontface = "bold",
              size = 3,
              angle=45, hjust=-0.1) +
    coord_cartesian(clip = "off") + 
    theme(
      plot.margin = margin(40, 20, 20, 20),
      legend.box.background = element_rect(color = "black", linewidth = 1),
      legend.box.margin = margin(5, 5, 5, 5),
      legend.key.size = unit(0.55, 'cm'), # Change legend key size
      legend.title = element_text(size = 12), # Change legend title font size
      legend.text = element_text(size = 10)) # Change legend text font size
  
  print(pn501y)
  print("Saving graph as .png file...")
  tree_name=deparse(substitute(tree))
  ggsave(pn501y, file=paste0(tree_name, "_plot.png"), height=7, width=8.5, units="in")
  
}
plot_tree_meta(tree)

# print("Generating plot for Gamma variant clade...")
# 
# alpha_seqs = metadata$taxon[grepl("Alpha", metadata$lineage)]
# alpha_node = getMRCA(tree, alpha_seqs)
# alpha_clade = extract.clade(tree, alpha_node)
# plot_tree_meta(alpha_clade)








