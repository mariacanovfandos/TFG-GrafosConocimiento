# ------------- CTD_curated_genes_diseases -------------

# ------------- LIMPIEZA --------------
# 1. Cargar librería
library(dplyr)
library(readr)
library(rdflib)
library(tidyverse)
library(data.table) 

# 2. Cargar el archivo saltando las líneas
datos_gen_enfermedad <- fread("https://ctdbase.org/reports/CTD_curated_genes_diseases.csv.gz", skip = 27, stringsAsFactors = FALSE)

datos_gen_enfermedad <- datos_gen_enfermedad %>%
  set_names(c("GeneSymbol", "GeneID", "DiseaseName", "DiseaseID", "DirectEvidence", 
              "OmimIDs", "PubMedIDs")) %>%
  # Seleccionar columnas de interés
  select(GeneSymbol, DiseaseID, DirectEvidence, PubMedIDs) %>%
  mutate(across(everything(), as.character)) %>%
  mutate(across(everything(), ~na_if(., ""))) %>%
  # Comprobar que hay GeneSymbol
  filter(!is.na(GeneSymbol) & !is.na(DiseaseID)) %>%
  distinct()

# ----------- SERIALIZACIÓN ------------

# 1. Inicializar el grafo vacío
grafo_gen_enfermedad <- rdf()

# 2. Definir prefijos 
rdf <- "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
biolink <- "https://w3id.org/biolink/vocab/"
sio <- "http://semanticscience.org/resource/"
schema <- "https://schema.org/"
mesh_prefix <- "https://id.nlm.nih.gov/mesh/"
obo <- "http://purl.obolibrary.org/obo/"
pubmed_base <- "https://pubmed.ncbi.nlm.nih.gov/"
assoc_base <- "http://tfg.org/gene_disease_association/"
gene_base <- "http://rdf.biogateway.eu/gene/9606/"

# 3. Bucle
for (i in 1:nrow(datos_gen_enfermedad)) {

  
  # --- EXTRAER LOS DATOS ---
  gen_symbol <- datos_gen_enfermedad$GeneSymbol[i] 
  enfermedad_id <- datos_gen_enfermedad$DiseaseID[i] 
  evidencia <- datos_gen_enfermedad$DirectEvidence[i] 
  pubmed <- datos_gen_enfermedad$PubMedIDs[i] 
  
  # --- CREAR LAS URIs DE ESTA FILA ---
  
  # Limpiamos MESH:
  id_enf_limpio <- sub("MESH:", "", enfermedad_id)
  uri_asociacion <- paste0(assoc_base, gen_symbol, "--", id_enf_limpio)
  uri_gen <- paste0(gene_base, gen_symbol)
  uri_enfermedad <- paste0(mesh_prefix, id_enf_limpio)
  
  # --- CONSTRUIR TRIPLETAS ---
  
  # Etiqueta del gen
  rdf_add(grafo_gen_enfermedad, 
          subject = uri_gen, 
          predicate = "http://www.w3.org/2000/01/rdf-schema#label", 
          object = as.character(datos_gen_enfermedad$GeneSymbol[i]))
  
  
  # Type
  rdf_add(grafo_gen_enfermedad, 
          subject = uri_asociacion, 
          predicate = paste0(rdf, "type"), 
          object = paste0(sio, "SIO_000983"))
  
  # A. El Sujeto es el Gen
  rdf_add(grafo_gen_enfermedad, 
          subject = uri_asociacion, 
          predicate = paste0(rdf, "subject"), 
          object = uri_gen)
  
  # B. El Objeto es la Enfermedad
  rdf_add(grafo_gen_enfermedad, 
          subject = uri_asociacion, 
          predicate = paste0(rdf, "object"), 
          object = uri_enfermedad)
  
  # Relación directa gen --> enfermedad
  rdf_add(grafo_gen_enfermedad, 
          subject = uri_gen, 
          predicate = paste0(obo, "RO_0002331"), 
          object = uri_enfermedad)
  
  # C. Evidencia Directa (si existe)
  if (!is.na(evidencia)) {
    lista_evidencias <- strsplit(evidencia, "\\|")[[1]]
    for (ev in lista_evidencias) {
      rdf_add(grafo_gen_enfermedad, 
              subject = uri_asociacion, 
              predicate = paste0(biolink, "has_evidence"), 
              object = ev)
    }
  }
  
  # D. PubMed
  if (!is.na(pubmed)) {
    lista_pubmeds <- strsplit(pubmed, "\\|")[[1]]
    for (pmid in lista_pubmeds) {
      uri_articulo <- paste0(pubmed_base, pmid)
      
      # Conectar asociación con artículo
      rdf_add(grafo_gen_enfermedad, 
              subject = uri_asociacion, 
              predicate = paste0(sio, "SIO_000772"), 
              object = uri_articulo)
      
      # Definir el tipo de artículo
      rdf_add(grafo_gen_enfermedad, 
              subject = uri_articulo, 
              predicate = paste0(rdf, "type"), 
              object = paste0(sio, "SIO_000154"))
      
      # Identificador del artículo
      rdf_add(grafo_gen_enfermedad, 
              subject = uri_articulo, 
              predicate = paste0(schema, "identifier"), 
              object = pmid)
    }
  }
  
  # Avance
  if (i %% 10000 == 0) {
    message(paste("Procesadas", i, "filas de", nrow(datos_gen_enfermedad)))
  }
}

# 4. Guardar grafo en archivo
rdf_serialize(grafo_gen_enfermedad, doc = "../RESULTADOS/CTD_Gene_Disease_association.ttl", format = "turtle")

