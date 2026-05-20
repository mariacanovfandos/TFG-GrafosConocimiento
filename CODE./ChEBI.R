# ------------- CHEBI -------------

# -------- LIMPIAR -------
library(dplyr)
library(data.table)
library(tidyverse)
library(rdflib)

# Carga de archivos
datos_compuestos <- fread("https://ftp.ebi.ac.uk/pub/databases/chebi/flat_files/compounds.tsv.gz", 
                          stringsAsFactors = FALSE)
datos_relaciones <- fread("https://ftp.ebi.ac.uk/pub/databases/chebi/flat_files/relation.tsv.gz",
                          stringsAsFactors = FALSE)
datos_estructuras <- fread("https://ftp.ebi.ac.uk/pub/databases/chebi/flat_files/structures.tsv.gz",
                           stringsAsFactors = FALSE)

# 2. Procesar archivos
nombres_chebi <- datos_compuestos %>%
  select(id, name, stars) %>%
  rename(ChEBI_ID = id, Chebi_Name = name)

roles_asignados <- datos_relaciones %>%
  filter(relation_type_id == 4) %>%
  select(init_id, final_id) %>%
  rename(ChEBI_ID = init_id, Role_ID = final_id)

nombres_roles <- datos_compuestos %>%
  select(id, name) %>%
  rename(Role_ID = id, Role_Name = name)

chebi_roles_final <- roles_asignados %>%
  inner_join(nombres_roles, by = "Role_ID") %>%
  group_by(ChEBI_ID) %>%
  summarise(Chemical_Role = paste(Role_Name, collapse = " | "))

# Cruce final con limpieza preventiva de NAs y strings vacíos
datos_chebi <- datos_estructuras %>%
  select(compound_id, standard_inchi_key) %>%
  rename(ChEBI_ID = compound_id, InChIKey = standard_inchi_key) %>%
  inner_join(nombres_chebi, by = "ChEBI_ID") %>%
  left_join(chebi_roles_final, by = "ChEBI_ID") %>%
  mutate(across(everything(), as.character)) %>%
  # Filtro inicial: eliminamos lo que R reconoce como NA explícito
  filter(!is.na(InChIKey) & InChIKey != "" & InChIKey != "NA") %>% 
  distinct()


# --------- SERIALIZAR ----------

grafo_chebi <- rdf()

# Prefijos
# Nota: BioGateway suele usar la base de OBO para ChEBI
chebi_prefix    <- "http://purl.obolibrary.org/obo/CHEBI_"
inchikey_prefix <- "https://identifiers.org/inchikey/" 
sio             <- "http://semanticscience.org/resource/"
rdfs            <- "http://www.w3.org/2000/01/rdf-schema#"
owl             <- "http://www.w3.org/2002/07/owl#"
rdf_type        <- "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"


for (i in 1:nrow(datos_chebi)) {
  
  # VALIDACIÓN DE SEGURIDAD INTERNA
  inchi_raw <- trimws(datos_chebi$InChIKey[i])
  chebi_id_raw <- trimws(datos_chebi$ChEBI_ID[i])
  
  # Solo procedemos si el InChIKey y el ID tienen contenido real
  if (!is.na(inchi_raw) && inchi_raw != "" && inchi_raw != "NA" &&
      !is.na(chebi_id_raw) && chebi_id_raw != "") {
    
    # Construcción de URIs limpias
    # Extraemos solo el número (ej. de "CHEBI:15377" a "15377")
    id_num     <- gsub("[^0-9]", "", chebi_id_raw) 
    uri_chebi  <- paste0(chebi_prefix, id_num)
    
    # Limpiamos el InChIKey (asegurando que no queden etiquetas de texto)
    inchi_val  <- sub("InChIKey=", "", inchi_raw)
    uri_inchi  <- paste0(inchikey_prefix, inchi_val)
    
    # A. Tipo y Equivalencia estructural
    rdf_add(grafo_chebi, 
            subject   = uri_chebi, 
            predicate = rdf_type, 
            object    = paste0(sio, "SIO_010004"))
    
    rdf_add(grafo_chebi, 
            subject   = uri_chebi, 
            predicate = paste0(owl, "sameAs"), 
            object    = uri_inchi)
    
    # B. Nombre de la molécula
    if (!is.na(datos_chebi$Chebi_Name[i]) && datos_chebi$Chebi_Name[i] != "") {
      rdf_add(grafo_chebi, 
              subject   = uri_chebi, 
              predicate = paste0(rdfs, "label"), 
              object    = as.character(datos_chebi$Chebi_Name[i]))
    }
    
    # C. Roles ("has attribute" -> SIO_000008)
    rol_texto <- datos_chebi$Chemical_Role[i]
    if (!is.na(rol_texto) && rol_texto != "" && rol_texto != "NA") {
      
      roles_separados <- unlist(strsplit(rol_texto, " \\| "))
      
      for (rol in roles_separados) {
        rol_limpio <- trimws(rol)
        if (rol_limpio != "") {
          # IMPORTANTE: Eliminamos comillas accidentales del texto del rol
          rol_limpio <- gsub("\"", "", rol_limpio)
          
          rdf_add(grafo_chebi, 
                  subject   = uri_chebi, 
                  predicate = paste0(sio, "SIO_000008"), 
                  object    = rol_limpio)
        }
      }
    }
  }
  
  # Avance
  if (i %% 10000 == 0) {
    message(paste("Procesadas", i, "filas de ", nrow(datos_chebi)))
  }
}

# Guardar
rdf_serialize(grafo_chebi, doc = "../RESULTADOS/ChEBI.ttl", format = "turtle")
