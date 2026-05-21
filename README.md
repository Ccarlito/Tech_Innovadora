# Innovatech_Chile
# Terraform AWS Infrastructure - Innovatech Chile

## Descripción
Infraestructura optimizada y automatizada gestionada con Terraform para desplegar la plataforma de Innovatech Chile siguiendo buenas prácticas de arquitectura y seguridad (DevSecOps):

* **VPC Personalizada:** Red aislada global para mitigar el radio de impacto de posibles ataques.
* **Separación de Entornos (Instancias EC2 independientes):** Una máquina virtual dedicada exclusivamente al Frontend y otra instancia de mayor rendimiento destinada al Backend (Microservicios + Base de datos).
* **NAT Gateway / Internet Gateway:** Configuración estricta de enrutamiento para permitir tráfico saliente seguro y control de peticiones entrantes.
* **Seguridad Perimetral Exclusiva (Security Groups):** Reglas estrictas que aíslan la base de datos y los microservicios de backend, permitiendo tráfico entrante únicamente desde el Security Group del Frontend.
* **Persistencia de Datos:** Arquitectura preparada para el acoplamiento de Docker Compose mediante volúmenes locales en el servidor de datos.

---

## 🗺️ Estructura del proyecto

```text
innovatech-chile-infra/
├── .gitignore
├── README.md
└── infra/
    ├── etapa_1/
    │   ├── main.tf
    │   └── outputs.tf
    └── etapa_2/
        ├── main.tf
        └── outputs.tf


🚀 Requisitos previos
Terraform CLI versión >= 1.0

AWS CLI instalado y configurado o variables de entorno temporales de AWS Academy.

Intalar Docker Desktop

Llave privada SSH compatible (vockey) disponible en el proveedor.


## ⚙️ Flujo de uso

1. Clona el repositorio.

git clone repo.

2. Abrir Docker Desktop.

2. Logearse en aws:

aws configure set aws_access_key_id TU_ACCESS_KEY_ID
aws configure set aws_secret_access_key TU_SECRET_ACCESS_KEY
aws configure set aws_session_token TU_SESSION_TOKEN
aws configure set default.region us-east-1

3. Inicializa Terraform:

# Primero, pararse en etapa_1 (crea los repositorios ECR)
cd infra/etapa_1
terraform init        # descarga los providers, solo la primera vez
terraform plan        # muestra qué va a crear, sin crear nada aún
terraform apply       # crea los 3 repositorios ECR en AWS

# Luego, pararse en etapa_2 (crea las EC2, SGs, VPC)
cd ../etapa_2
terraform init
terraform plan
cd infra/etapa_2
terraform apply -var="key_pair_name=innovatech-key"       # crea las instancias EC2 y toda la red


📦¿Qué despliega este proyecto?
Módulo de Red y Conectividad: Diseña la VPC, subredes públicas y pasarelas de red (Internet Gateway / NAT Gateway) para garantizar la alta disponibilidad y la salida segura a internet de los servidores internos.

Módulo de Cómputo y Seguridad: Despliega servidores virtuales dedicados (EC2 Linux) aprovisionando llaves SSH públicas y enlazando Security Groups herméticos que bloquean de forma nativa puertos críticos como el 3306 (MySQL) y los puertos lógicos del backend.

Interconexión Dinámica: Gestiona la transferencia de datos entre etapas mediante variables de entrada y bloques outputs que exponen las direcciones IP públicas requeridas por los pipelines de CI/CD.

4. Cuando termina el terraform apply de etapa_2, los outputs aparecen directo en la terminal:
Outputs:

frontend_public_ip = "54.123.45.67"
backend_public_ip  = "54.123.45.89"

Si los cerraste o no los viste, los recuperas con:
cd infra/etapa_2
terraform output

También los puedes ver en la consola de AWS.

5. Editar los secrets de github actions segun sus credenciales y otras variables:

    Nombre del Secret   |           Valor         |   Proposito
AWS_ACCESS_KEY_ID       |     De AWS Academy      |     Autenticarse en AWS
AWS_SECRET_ACCESS_KEY   |     De AWS Academy      |     Autenticarse en AWS
AWS_SESSION_TOKEN       |     De AWS Academy      |     Autenticarse en AWS
AWS_ACCOUNT_ID          |     Tu número de cuenta AWS (12 dígitos) |    Armar la URL del ECR
EC2_SSH_KEY             |     Contenido completo del .pem          |    Conectarse por SSH a la EC2
EC2_BACKEND_HOST        |     IP que salió del terraform output    |    Saber a qué EC2 conectarse (solo en los 2 repos de backend)
EC2_FRONTEND_HOST       |     IP que salió del terraform output    |    Saber a qué EC2 conectarse (solo en el repo de frontend)

6. Subir docker-compose.yml y .env a la EC2 backend
ssh -i tu-clave.pem ec2-user@<backend_ip> "mkdir -p /home/ec2-user/app"
scp -i tu-clave.pem docker-compose.yml ec2-user@<backend_ip>:/home/ec2-user/app/
scp -i tu-clave.pem .env ec2-user@<backend_ip>:/home/ec2-user/app/

7. Subir docker-compose.yml a la EC2 frontend (solo necesita levantar el contenedor)
ssh -i tu-clave.pem ec2-user@<frontend_ip> "mkdir -p /home/ec2-user/app"
scp -i tu-clave.pem docker-compose.yml ec2-user@<frontend_ip>:/home/ec2-user/app/

8. Push a release/0.1.1 → el workflow se dispara solo

🛡️ Mejores prácticas incluidas
Principio de Menor Privilegio: Los Security Groups actúan como firewalls a nivel de instancia, impidiendo que internet tenga visibilidad directa del Backend y la Base de Datos.

Infraestructura como Código (IaC): Todo el entorno es reproducible, eliminando configuraciones manuales propensas a errores humanos en la consola web.

Seguridad en el Control de Versiones: Uso estricto de .gitignore para bloquear la subida de estados locales de Terraform (.tfstate), protegiendo contraseñas o credenciales temporales del escaneo público.


🔮 Cómo extender este proyecto
Implementar un Balanceador de Carga (ALB): Distribuir el tráfico entrante del puerto 80 del frontend hacia múltiples zonas de disponibilidad.

Escalado Automático (Auto Scaling Groups): Añadir políticas basadas en consumo de CPU para incrementar dinámicamente el número de servidores EC2 ante alta demanda.

Migración a Base de Datos Gestionada (AWS RDS): Desacoplar el contenedor MySQL del EC2 de backend y migrarlo a un servicio administrado con respaldos automáticos y Multi-AZ para garantizar tolerancia a fallos.

Automatización CI/CD: Integración completa con GitHub Actions en la rama deploy utilizando la gestión nativa de Repository Secrets.

