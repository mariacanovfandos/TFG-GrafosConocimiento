# ------------- CTD_chem_gene_ixns -------------

# ------------- LIMPIEZA --------------
# 1. Cargar librerías
library(dplyr)
library(readr)
library(data.table)
library(tidyverse)

# 2. Leer archivo
datos_quimico_gen <- fread("https://ctdbase.org/reports/CTD_chem_gene_ixns.csv.gz", 
                           skip = 27, stringsAsFactors = FALSE)

# 3. Limpiar archivo
datos_quimico_gen <- datos_quimico_gen %>%
  set_names(c("ChemicalName", "ChemicalID", "CasRN", "GeneSymbol", "GeneID", 
              "GeneForms", "Organism", "OrganismID", "Interaction", 
              "InteractionActions", "PubMedIDs")) %>%
  select(ChemicalID, GeneSymbol, OrganismID, InteractionActions, PubMedIDs) %>%
  mutate(across(everything(), as.character)) %>%
  mutate(across(everything(), ~na_if(., ""))) %>%
  filter(OrganismID == "9606") %>%
  filter(!is.na(ChemicalID) & !is.na(GeneSymbol)) %>%
  distinct()


# ----------- SERIALIZACIÓN ------------

# 1. Guardar grafo
ruta_guardado_cg <- "/Users/mersmac/Desktop/TFG/RESULTADOS/Chem_gene_interactions2.ttl"
cat("", file = ruta_guardado_cg)

rdf <- "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
rdfs <- "http://www.w3.org/2000/01/rdf-schema#"
sio <- "http://semanticscience.org/resource/"
schema <- "https://schema.org/"
bao <- "http://www.bioassayontology.org/bao#"

mesh_prefix <- "https://id.nlm.nih.gov/mesh/"
gene_base <- "http://rdf.biogateway.eu/gene/9606/" 
assoc_base <- "http://tfg.org/chemical_gene_association/" 
pubmed_base <- "https://pubmed.ncbi.nlm.nih.gov/"

# 2. Bucle
for (i in 1:nrow(datos_quimico_gen)) {
  
  # Extraer datos
  chem_id <- datos_quimico_gen$ChemicalID[i]
  gene_symbol <- datos_quimico_gen$GeneSymbol[i]
  interaccion_val <- datos_quimico_gen$InteractionActions[i]
  pubmed <- datos_quimico_gen$PubMedIDs[i]
  
  chem_limpio <- sub("MESH:", "", chem_id)
  
  # Crear URI
  uri_asociacion <- paste0("<", assoc_base, chem_limpio, "--", gene_symbol, ">")
  uri_quimico <- paste0("<", mesh_prefix, chem_limpio, ">")
  uri_gen <- paste0("<", gene_base, gene_symbol, ">")
  
  # Vector temporal para guardar líneas de texto de la iteración
  lineas <- c()
  
  # Tripletas Estructurales
  lineas <- c(lineas, paste(uri_asociacion, 
                            paste0("<", rdf, "type>"), 
                            paste0("<", sio, "SIO_001257> .")))
  
  lineas <- c(lineas, paste(uri_asociacion, 
                            paste0("<", rdf, "subject>"), 
                            uri_quimico, "."))
  
  lineas <- c(lineas, paste(uri_asociacion, 
                            paste0("<", rdf, "object>"), 
                            uri_gen, "."))
  
  lineas <- c(lineas, paste(uri_gen, 
                            paste0("<", rdfs, "label>"), 
                            paste0("\"", datos_quimico_gen$GeneSymbol[i], "\""), 
                            "."))
  
  lineas <- c(lineas, paste(uri_gen, 
                            paste0("<", rdf, "type>"), 
                            paste0("<", sio, "SIO_010035> .")))

   lineas <- c(lineas, paste(uri_quimico, 
                            paste0("<", bao, "BAO_0000211>"), 
                            uri_gen, "."))
  
  # Tripletas de InteractionActions (BAO)
  if (!is.na(interaccion_val)) {
    lista_acciones <- strsplit(interaccion_val, "\\|")[[1]]
    for (accion in lista_acciones) {
      lineas <- c(lineas, paste(uri_asociacion, 
                                paste0("<", bao, "BAO_0000196>"), 
                                paste0("\"", accion, "\" .")))
    }
  }
  
  # Tripletas de PubMed
  if (!is.na(pubmed) && pubmed != "") {
    lista_pubmeds <- strsplit(pubmed, "\\|")[[1]]
    for (pmid in lista_pubmeds) {
      uri_articulo <- paste0("<", pubmed_base, pmid, ">")
      
      lineas <- c(lineas, paste(uri_asociacion, 
                                paste0("<", sio, "SIO_000772>"), 
                                uri_articulo, "."))
      lineas <- c(lineas, paste(uri_articulo, 
                                paste0("<", rdf, "type>"), 
                                paste0("<", sio, "SIO_000154> .")))
      lineas <- c(lineas, paste(uri_articulo, 
                                paste0("<", schema, "identifier>"), 
                                paste0("\"", pmid, "\" .")))
    }
  }
  
  # Escribir bloque de texto en el archivo
  cat(paste(lineas, collapse = "\n"), "\n", file = ruta_guardado_cg, append = TRUE)
  
  # Avance
  if (i %% 10000 == 0) {
    message(paste("Procesadas", i, "filas de", nrow(datos_quimico_gen)))
  }
}
