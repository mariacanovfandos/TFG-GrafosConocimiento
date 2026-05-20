# ------------- DRUGBANK -------------

#-------- LIMPIAR ---------

library(dplyr)
library(data.table)
library(tidyverse)
library(rdflib)

# 1. Leer archivo
datos_drugbank <- fread("https://go.drugbank.com/releases/5-1-17/downloads/all-drugbank-vocabulary?_gl=1*1y4a64v*_up*MQ..*_ga*MTU3ODU2OTI5NC4xNzc2NDExODUx*_ga_DDLJ7EEV9M*czE3NzY0MTE4NTAkbzEkZzEkdDE3NzY0MTE4ODAkajMwJGwwJGgw",
                        stringsAsFactors = FALSE)


# 2. Limpieza 
datos_drugbank <- datos_drugbank %>%
  select(`DrugBank ID`, `Common name`, `Standard InChI Key`) %>%
  rename(DrugBank_ID = `DrugBank ID`, 
         Name = `Common name`, 
         InChIKey = `Standard InChI Key`) %>%
  # Limpiar las celdas en blanco por NAs reales
  mutate(across(everything(), ~na_if(., ""))) %>%
  filter(!is.na(DrugBank_ID) & !is.na(InChIKey))

#--------- SERIALIZAR ----------

# 1. Grafo vacío
grafo_drugbank <- rdf()

# 2. Prefijos
drugbank_prefix <- "http://identifiers.org/drugbank/"
inchikey_prefix <- "https://identifiers.org/inchikey/"
owl <- "http://www.w3.org/2002/07/owl#"
rdf_type <- "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
sio <- "http://semanticscience.org/resource/"
rdfs <- "http://www.w3.org/2000/01/rdf-schema#"

# 3. Bucle
for (i in 1:nrow(datos_drugbank)) {
  
  db_id <- datos_drugbank$DrugBank_ID[i]
  inchi <- datos_drugbank$InChIKey[i]
  Name <- datos_drugbank$Name[i]
  
  # URIs
  uri_drugbank <- paste0(drugbank_prefix, db_id)
  uri_inchi <- paste0(inchikey_prefix, inchi)
  
  # A. Crear el nodo de DrugBank (Es un Químico)
  rdf_add(grafo_drugbank, 
          subject = uri_drugbank, 
          predicate = rdf_type, 
          object = paste0(sio, "SIO_010004"))
  
  # B. Añadir nombre
  rdf_add(grafo_drugbank, 
          subject = uri_drugbank, 
          predicate = paste0(rdfs, "label"), 
          object = Name)
  
  # C. Unir a InChIKey
  rdf_add(grafo_drugbank, 
          subject = uri_drugbank, 
          predicate = paste0(owl, "sameAs"), 
          object = uri_inchi)
  
  # Avance
  if (i %% 10000 == 0) {
    message(paste("Procesadas", i, "filas de DrugBank"))
  }
}

# 4. Guardar grafo
ruta_guardado <- "/Users/mersmac/Desktop/TFG/RESULTADOS/drugbank_vocabulary.ttl"
rdf_serialize(grafo_drugbank, doc = ruta_guardado, format = "turtle")
