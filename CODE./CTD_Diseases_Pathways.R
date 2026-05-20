# ------------- CTD_diseases_pathways -------------

# ------------- LIMPIEZA --------------
# 1. Cargar librerías
library(dplyr)
library(readr)
library(data.table)
library(tidyverse)

# 2. Leer archivo
datos_enfermedad_ruta <- fread("https://ctdbase.org/reports/CTD_diseases_pathways.csv.gz", 
                               skip = 27, stringsAsFactors = FALSE)

# 3. Limpiar archivo
datos_enfermedad_ruta <- datos_enfermedad_ruta %>%
  set_names(c("DiseaseName", "DiseaseID", "PathwayName", 
              "PathwayID", "InferenceGeneSymbol")) %>%
  select(DiseaseName, DiseaseID, PathwayName, PathwayID) %>%
  mutate(across(everything(), as.character)) %>%
  mutate(across(everything(), ~na_if(., ""))) %>%
  filter(!is.na(DiseaseID) & !is.na(PathwayID)) %>%
  distinct()

# ----------- SERIALIZACIÓN ------------

# 1. Guardar grafo
ruta_guardado_asociaciones <- "../RESULTADOS/CTD_Diseases_Pathways_association.ttl"
cat("", file = ruta_guardado_asociaciones)

# 2. Prefijos
rdf <- "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
rdfs <- "http://www.w3.org/2000/01/rdf-schema#"
sio <- "http://semanticscience.org/resource/"
obo <- "http://purl.obolibrary.org/obo/"
schema <- "https://schema.org/"
owl <- "http://www.w3.org/2002/07/owl#"
biolink <- "https://w3id.org/biolink/vocab/"

mesh_prefix <- "https://id.nlm.nih.gov/mesh/"
omim_prefix <- "http://purl.bioontology.org/ontology/OMIM/"
kegg_base <- "http://identifiers.org/kegg.pathway/"
reactome_base <- "http://identifiers.org/reactome/"
assoc_base <- "http://tfg.org/disease_pathway_association/"

# 3. Bucle 
for (i in 1:nrow(datos_enfermedad_ruta)) { 
  
  # --- EXTRAER LOS DATOS ---
  enf_nombre <- datos_enfermedad_ruta$DiseaseName[i]
  enf_id <- datos_enfermedad_ruta$DiseaseID[i] 
  ruta_nombre <- datos_enfermedad_ruta$PathwayName[i]
  ruta_id <- datos_enfermedad_ruta$PathwayID[i] 
  
  # --- LIMPIAR IDs Y CREAR URIs ---
  

  if (grepl("^MESH:", enf_id)) {
    id_enf_limpio <- sub("MESH:", "", enf_id)
    uri_enfermedad <- paste0("<", mesh_prefix, id_enf_limpio, ">")
  } else if (grepl("^OMIM:", enf_id)) {
    id_enf_limpio <- sub("OMIM:", "", enf_id)
    uri_enfermedad <- paste0("<", omim_prefix, id_enf_limpio, ">")
  } else {
    next 
  }
  
  if (grepl("^KEGG:", ruta_id)) {
    id_ruta_limpio <- sub("KEGG:", "", ruta_id)
    uri_ruta <- paste0("<", kegg_base, id_ruta_limpio, ">")
  } else if (grepl("^REACT:", ruta_id)) {
    id_ruta_limpio <- sub("REACT:", "", ruta_id)
    uri_ruta <- paste0("<", reactome_base, id_ruta_limpio, ">")
  } else {
    next 
  }
  
  # URI
  uri_asociacion <- paste0("<", assoc_base, id_enf_limpio, "--", id_ruta_limpio, ">") 
  
  
  # --- CONSTRUIR TRIPLETAS ---
  lineas <- c()
  
  # NODO PUENTE (Asociación)
  # A. Tipo: biolink:Association
  lineas <- c(lineas, paste(uri_asociacion, 
                            paste0("<", rdf, "type>"), 
                            paste0("<", biolink, "Association> .")))
  
  # NODO ENFERMEDAD (Sujeto)
  # B. Conexión del puente a la enfermedad
  lineas <- c(lineas, paste(uri_asociacion, 
                            paste0("<", rdf, "subject>"), 
                            uri_enfermedad, "."))
  
  # C. Tipo: sio:SIO_010299 "disease"
  lineas <- c(lineas, paste(uri_enfermedad, 
                            paste0("<", rdf, "type>"), 
                            paste0("<", sio, "SIO_010299> .")))
  
  # D. Label: DiseaseName
  lineas <- c(lineas, paste(uri_enfermedad, 
                            paste0("<", rdfs, "label>"), 
                            paste0("\"", enf_nombre, "\" .")))
  
  # E. Identifier: DiseaseID (Guardamos el ID limpio sin prefijo por coherencia)
  lineas <- c(lineas, paste(uri_enfermedad, 
                            paste0("<", schema, "identifier>"), 
                            paste0("\"", id_enf_limpio, "\" .")))
  
  # F. Relación Enfermedad -> Ruta ("involved in" RO_0002331)
  lineas <- c(lineas, paste(uri_enfermedad, 
                            paste0("<", obo, "RO_0002331>"), 
                            uri_ruta, "."))
  
  # NODO RUTA (Objeto)
  # 1. Conexión del puente a la ruta
  lineas <- c(lineas, paste(uri_asociacion, 
                            paste0("<", rdf, "object>"), 
                            uri_ruta, "."))
  
  # 2. Tipo: sio:SIO_001107 "pathway"
  lineas <- c(lineas, paste(uri_ruta, 
                            paste0("<", rdf, "type>"),
                            paste0("<", sio, "SIO_001107> .")))
  
  # 3. Label: PathwayName
  lineas <- c(lineas, paste(uri_ruta, 
                            paste0("<", rdfs, "label>"), 
                            paste0("\"", ruta_nombre, "\" .")))
  
  # 4. Identifier: PathwayID
  lineas <- c(lineas, paste(uri_ruta, 
                            paste0("<", schema, "identifier>"), 
                            paste0("\"", id_ruta_limpio, "\" .")))
  
  # Guardar este bloque en el archivo
  cat(paste(lineas, collapse = "\n"), "\n", file = ruta_guardado_asociaciones, append = TRUE)
  
  # Mensaje de progreso
  if (i %% 10000 == 0) {
    message(paste("Procesadas", i, "filas de", nrow(datos_enfermedad_ruta)))
  }
}
