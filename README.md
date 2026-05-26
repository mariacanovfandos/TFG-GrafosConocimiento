# Grafos de Conocimiento Para el Estudio de la Neurotoxicidad por Fármacos Antitumorales y Agentes Dopantes


Este repositorio contiene el código fuente, los scripts de procesamiento y las consultas SPARQL asociados al Trabajo de Fin de Grado para el desarrollo de un Grafo de Conocimiento Semántico (Knowledge Graph). 
El proyecto extrae, procesa y serializa datos de la *Comparative Toxicogenomics Database* (CTD), ChEBI y DrugBank para modelar computacionalmente los efectos de diversos compuestos químicos en la salud, poniendo especial énfasis en el análisis de fármacos antitumorales y agentes dopantes.


## Objetivos
El objetivo principal de este trabajo es explorar y analizar las interacciones complejas y los efectos neurotoxicológicos subyacentes al uso de fármacos antitumorales y agentes dopantes. Para ello, se integra información procedente de diversas bases de datos biomédicas (como ChEBI, DrugBank y CTD) en un KG, representando de manera estructurada las relaciones entre compuestos, genes, rutas metabólicas y fenotipos. Este enfoque aporta una herramienta avanzada que permite extraer conocimiento, como mecanismos de toxicidad que no resultan evidentes al analizar las bases de datos de forma aislada. Además, el modelo se diseña de forma interoperable con la red BioGateway, lo que amplia sus recursos y permite realizar investigaciones más profundas sobre el impacto biológico de los fármacos.

Para alcanzar este propósito general, se proponen los siguientes objetivos específicos:
1. Estudiar las bases de datos biomédicas y tecnologías semánticas actuales para la extracción de relaciones toxicológicas y genéticas.
2. Desarrollar un esquema semántico que defina de forma estructurada las relaciones entre compuestos químicos, procesos celulares y efectos en la salud.
3. Generar un KG, estandarizando e integrando los datos procedentes de las fuentes científicas para garantizar su consistencia con la red BioGateway.
4. Evaluar los efectos biológicos y la neurotoxicidad combinada mediante la ejecución de consultas de competencia.


## Estructura del Repositorio
- `/CODE/`: Scripts en R para la extracción, limpieza (`dplyr`, `data.table`) y serialización a tripletas RDF (`rdflib`). Contiene los módulos secuenciales para procesar químicos, enfermedades, genes y sus interacciones.
- `/RESULTADOS/`: Directorio de salida donde se alojan los archivos `.ttl` generados, listos para su importación al motor de grafos.
- `/SPARQL/`: Código de las consultas realizadas en el trabajo.
- `/DIAGRAMA CONCEPTUAL/`: Documentación visual y técnica de la red.
    - `Esquema Semántico.png`: Representación gráfica de la arquitectura del grafo.
    - `Prefijos Oontologias.xlsx`: Diccionario de prefijos y namespaces utilizados (MESH, OMIM, SIO, etc.).
    - `README.md`: Explicación detallada de la lógica de relaciones y la jerarquía de las ontologías.


## Guía de Ejecución
### 1. Pre-requisitos
El preprocesamiento de datos está programado en R. Se requieren las siguientes librerías: ``R install.packages(c("dplyr", "readr", "data.table", "tidyverse", "rdflib"))´´

### 2. Generación del KG
Los scripts descargan automáticamente los datos de CTD, ChEBI y DrugBank. Al ejecutar los scripts presentes en la carpeta /CODE/, se realiza el procesamiento y serialización de los datos de cada una de las bases mencionadas, almacenando los datos en formato Turtle. Para algunos archivos, debido a su gran tamaño, resulta necesario cambiar la forma de almacenar los datos resultantes del procesamiento y serialización, usando el formato N-Triples, el cual es un subconjunto de Turtle.

### 3. Exploración en GraphDB
Cargar los ficheros resultantes del paso anterior en un repositorio de Ontotext GraphDB y utilizar las archivos de la carpeta /SPARQL/ para interrogar al grafo y reproducir las consultas del trabajo.



