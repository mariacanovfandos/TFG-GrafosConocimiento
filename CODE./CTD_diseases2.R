# ------------- CTD_diseases -------------

# ------------- LIMPIEZA --------------

# 1. Cargar paquetes
library(rdflib)
library(dplyr)
library(data.table)
library(tidyverse)

datos_enfermedades <- fread("https://ctdbase.org/reports/CTD_diseases.csv.gz", 
                            skip = 27, stringsAsFactors = FALSE)

# 2. Limpiar archivo
datos_enfermedades <- datos_enfermedades %>%
  set_names(c("DiseaseName", "DiseaseID", "AltDiseaseIDs", "Definition", "ParentIDs",
              "TreeNumbers", "ParentTreeNumbers", "Synonyms", "SlimMappings")) %>%
  select(DiseaseName, DiseaseID, Definition) %>%
  mutate(across(everything(), as.character)) %>%
  mutate(across(everything(), ~na_if(., ""))) %>%
  filter(!is.na(DiseaseID)) %>%
  distinct()


# ----------- SERIALIZACIÓN ------------

# 1. Iniciar grafo vacío
grafo_enfermedades <- rdf()

# 2. Definir los prefijos
sio <- "http://semanticscience.org/resource/"
rdfs <- "http://www.w3.org/2000/01/rdf-schema#"
rdf_type <- "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
obo <- "http://purl.obolibrary.org/obo/"
schema = "https://schema.org/"
mesh_prefix <- "https://id.nlm.nih.gov/mesh/" 
omim_prefix <- "http://purl.bioontology.org/ontology/OMIM/"
skos <- "http://www.w3.org/2004/02/skos/core#"

# 3. Bucle
for (i in 1:nrow(datos_enfermedades)) {
  
  # Extraer datos de fila actual
  DiseaseName <- datos_enfermedades$DiseaseName[i]
  ID_inicial <- datos_enfermedades$DiseaseID[i]
  Definicion <- datos_enfermedades$Definition[i]
  
  # Crear URI según la base de datos de origen
  if (grepl("^MESH:", ID_inicial)) {
    id_limpio <- sub("MESH:", "", ID_inicial)
    uri_enfermedad <- paste0(mesh_prefix, id_limpio)
  } else if (grepl("^OMIM:", ID_inicial)) {
    id_limpio <- sub("OMIM:", "", ID_inicial)
    uri_enfermedad <- paste0(omim_prefix, id_limpio)
  } else {
    uri_enfermedad <- paste0("http://unknown.org/disease/", ID_inicial)
  }
  
  # --- TRIPLETAS ---
  
  # Tripleta A: nodo es de tipo "Enfermedad" (SIO_010299)
  rdf_add(grafo_enfermedades, 
          subject = uri_enfermedad, 
          predicate = rdf_type, 
          object = paste0(sio, "SIO_010299"))
  
  # Tripleta B: asignar su nombre en texto normal
  rdf_add(grafo_enfermedades, 
          subject = uri_enfermedad, 
          predicate = paste0(rdfs, "label"), 
          object = DiseaseName)
  
  # Tripleta C: asignar su identificador
  rdf_add(grafo_enfermedades, 
          subject = uri_enfermedad, 
          predicate = paste0(schema, "identifier"), 
          object = ID_inicial)
  
  #Definition
  if (!is.na(Definicion)) {
    rdf_add(grafo_enfermedades, 
            subject = uri_enfermedad, 
            predicate = paste0(skos, "definition"), 
            object = Definicion)
  }
  
  # Avance
  if (i %% 10000 == 0) {
    message(paste("Procesadas", i, "filas de", nrow(datos_enfermedades)))
  }
}


# 5. Guardar el grafo definitivo en un archivo
ruta_guardado <- "/Users/mersmac/Desktop/TFG/RESULTADOS/Diseases2_ctd.ttl"
rdf_serialize(grafo_enfermedades, doc = ruta_guardado, format = "turtle")
