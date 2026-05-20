# ------------- CTD_chemicals -------------

# ------------ LIMPIEZA -------------
# 1. Cargar paquetes
library(readr)
library(dplyr)
library(data.table)
library(tidyverse)
library(rdflib)

datos_quimicos <- fread("https://ctdbase.org/reports/CTD_chemicals.csv.gz", 
                        skip = 27, stringsAsFactors = FALSE)

datos_quimicos <- datos_quimicos %>%
  set_names(c("ChemicalName", "ChemicalID", "CasRN", "PubChemCID", "PubChemSID", 
              "DTXSID", "InChIKey", "Definition", "ParentIDs", 
              "TreeNumbers", "ParentTreeNumbers", "MESHSynonyms", "CTDCuratedSynonyms")) %>%
  # Seleccionar columnas de interés
  select(ChemicalName, ChemicalID, InChIKey, Definition) %>%
  mutate(across(everything(), ~na_if(., "")))

# ----------- SERIALIZACIÓN ------------

# 1. Iniciar grafo vacío
grafo_quimicos <- rdf()

# 2. Definir los prefijos
sio <- "http://semanticscience.org/resource/"
rdfs <- "http://www.w3.org/2000/01/rdf-schema#"
rdf_type <- "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
mesh_prefix <- "https://id.nlm.nih.gov/mesh/" 
schema <- "https://schema.org/"
owl <- "http://www.w3.org/2002/07/owl#"
inchikey_prefix <- "https://identifiers.org/inchikey/"
skos <- "http://www.w3.org/2004/02/skos/core#"
rdf <- "http://www.w3.org/1999/02/22-rdf-syntax-ns#"

# 3. Bucle
for (i in 1:nrow(datos_quimicos)) {
  
  ChemicalName <- datos_quimicos$ChemicalName[i]
  ID_inicial <- datos_quimicos$ChemicalID[i]  
  InChIKey <- datos_quimicos$InChIKey[i]
  Definicion <- datos_quimicos$Definition[i] 
  
  ID_solo_codigo <- sub("MESH:", "", ID_inicial)
  uri_quimico <- paste0(mesh_prefix, ID_solo_codigo)
  
  # --- TRIPLETAS ---
  
  # A. Tipo (Químico)
  rdf_add(grafo_quimicos, 
          subject = uri_quimico, 
          predicate = rdf_type, 
          object = paste0(sio, "SIO_010004"))
  
  # B. Label
  rdf_add(grafo_quimicos, 
          subject = uri_quimico, 
          predicate = paste0(rdfs, "label"), 
          object = ChemicalName)
  
  # C. Identificador
  rdf_add(grafo_quimicos, 
          subject = uri_quimico, 
          predicate = paste0(schema, "identifier"), 
          object = ID_solo_codigo)
  
  # D. sameAs (InChIKey)
  if (!is.na(InChIKey)) {
    uri_inchi <- paste0(inchikey_prefix, InChIKey)
    rdf_add(grafo_quimicos, 
            subject = uri_quimico, 
            predicate = paste0(owl, "sameAs"), 
            object = uri_inchi)
  }
  
  # E. Definición (SKOS). Solo se añade si la molécula tiene definición (no es NA)
  if (!is.na(Definicion)) {
    rdf_add(grafo_quimicos, 
            subject = uri_quimico, 
            predicate = paste0(skos, "definition"), 
            object = Definicion)
  }
  
  # Avance
  if (i %% 10000 == 0) {
    message(paste("Procesadas", i, "filas de ", nrow(datos_quimicos)))
  }
}

# 4. Guardar el archivo
rdf_serialize(grafo_quimicos, doc = "../RESULTADOS/CTD_Chemicals.ttl", format = "turtle")
