#!/bin/bash

# Verificar si se proporcionó un nombre de entidad
if [ -z "$1" ]; then
  echo "Uso: $0 <EntityName>"
  exit 1
fi

# Configuración
ENTITY_NAME="$1"
ENTITY_NAME_LOWER=$(echo "$ENTITY_NAME" | tr '[:upper:]' '[:lower:]')
PROJECT_NAME="$ENTITY_NAME_LOWER"

# Crear estructura de carpetas
mkdir -p "$PROJECT_NAME/cmd"
mkdir -p "$PROJECT_NAME/models"
mkdir -p "$PROJECT_NAME/repository"
mkdir -p "$PROJECT_NAME/usecases"
mkdir -p "$PROJECT_NAME/handler"
mkdir -p "$PROJECT_NAME/config"

# Inicializar go module
cd "$PROJECT_NAME" || exit
go mod init "$PROJECT_NAME"

# Ejecutar go mod tidy en el directorio del proyecto
go mod tidy

# Volver al directorio raíz
cd ..

# Archivo modelo e interfaces
cat <<EOL > "$PROJECT_NAME/models/${ENTITY_NAME_LOWER}.go"
package models

type ${ENTITY_NAME} struct {
    ID       int64  \`json:"id"\`
    Name     string \`json:"name"\`
    Email    string \`json:"email"\`
}

type ${ENTITY_NAME}Repository interface {
    Get${ENTITY_NAME}ByID(id int64) (*${ENTITY_NAME}, error)
    Create${ENTITY_NAME}(entity *${ENTITY_NAME}) error
    Update${ENTITY_NAME}(entity *${ENTITY_NAME}) error
    Delete${ENTITY_NAME}(id int64) error
}

type ${ENTITY_NAME}Usecase interface {
    Register${ENTITY_NAME}(entity *${ENTITY_NAME}) error
    Get${ENTITY_NAME}Profile(id int64) (*${ENTITY_NAME}, error)
}
EOL

# Archivo repositorio
cat <<EOL > "$PROJECT_NAME/repository/${ENTITY_NAME_LOWER}_repository.go"
package repository

import (
    "github.com/jmoiron/sqlx"
    "${PROJECT_NAME}/models"
)

type ${ENTITY_NAME}RepositoryImpl struct {
    db *sqlx.DB
}

func New${ENTITY_NAME}Repository(db *sqlx.DB) models.${ENTITY_NAME}Repository {
    return &${ENTITY_NAME}RepositoryImpl{db: db}
}

// Implementación de Get${ENTITY_NAME}ByID
func (repo *${ENTITY_NAME}RepositoryImpl) Get${ENTITY_NAME}ByID(id int64) (*models.${ENTITY_NAME}, error) {
    var entity models.${ENTITY_NAME}
    err := repo.db.Get(&entity, "SELECT * FROM ${ENTITY_NAME_LOWER}s WHERE id = $1", id)
    if err != nil {
        return nil, err
    }
    return &entity, nil
}

// Implementación de Create${ENTITY_NAME}
func (repo *${ENTITY_NAME}RepositoryImpl) Create${ENTITY_NAME}(entity *models.${ENTITY_NAME}) error {
    _, err := repo.db.Exec("INSERT INTO ${ENTITY_NAME_LOWER}s (name, email) VALUES ($1, $2)", entity.Name, entity.Email)
    return err
}

// Implementación de Update${ENTITY_NAME}
func (repo *${ENTITY_NAME}RepositoryImpl) Update${ENTITY_NAME}(entity *models.${ENTITY_NAME}) error {
    _, err := repo.db.Exec("UPDATE ${ENTITY_NAME_LOWER}s SET name=$1, email=$2 WHERE id=$3", entity.Name, entity.Email, entity.ID)
    return err
}

// Implementación de Delete${ENTITY_NAME}
func (repo *${ENTITY_NAME}RepositoryImpl) Delete${ENTITY_NAME}(id int64) error {
    _, err := repo.db.Exec("DELETE FROM ${ENTITY_NAME_LOWER}s WHERE id=$1", id)
    return err
}
EOL

# Archivo de caso de uso
cat <<EOL > "$PROJECT_NAME/usecases/${ENTITY_NAME_LOWER}_usecase.go"
package usecases

import (
    "${PROJECT_NAME}/models"
)

type ${ENTITY_NAME}UsecaseImpl struct {
    repo models.${ENTITY_NAME}Repository
}

func New${ENTITY_NAME}Usecase(repo models.${ENTITY_NAME}Repository) models.${ENTITY_NAME}Usecase {
    return &${ENTITY_NAME}UsecaseImpl{repo: repo}
}

func (uc *${ENTITY_NAME}UsecaseImpl) Register${ENTITY_NAME}(entity *models.${ENTITY_NAME}) error {
    return uc.repo.Create${ENTITY_NAME}(entity)
}

func (uc *${ENTITY_NAME}UsecaseImpl) Get${ENTITY_NAME}Profile(id int64) (*models.${ENTITY_NAME}, error) {
    return uc.repo.Get${ENTITY_NAME}ByID(id)
}
EOL

# Archivo handler
cat <<EOL > "$PROJECT_NAME/handler/${ENTITY_NAME_LOWER}_handler.go"
package handler

import (
    "encoding/json"
    "net/http"
    "strconv"

    "${PROJECT_NAME}/models"
)

type ${ENTITY_NAME}Handler struct {
    usecase models.${ENTITY_NAME}Usecase
}

func New${ENTITY_NAME}Handler(usecase models.${ENTITY_NAME}Usecase) *${ENTITY_NAME}Handler {
    return &${ENTITY_NAME}Handler{usecase: usecase}
}

func (h *${ENTITY_NAME}Handler) Register${ENTITY_NAME}(w http.ResponseWriter, r *http.Request) {
    var entity models.${ENTITY_NAME}
    if err := json.NewDecoder(r.Body).Decode(&entity); err != nil {
        http.Error(w, "Invalid input", http.StatusBadRequest)
        return
    }
    if err := h.usecase.Register${ENTITY_NAME}(&entity); err != nil {
        http.Error(w, "Failed to register", http.StatusInternalServerError)
        return
    }
    w.WriteHeader(http.StatusCreated)
}

func (h *${ENTITY_NAME}Handler) Get${ENTITY_NAME}Profile(w http.ResponseWriter, r *http.Request) {
    id, err := strconv.ParseInt(r.URL.Query().Get("id"), 10, 64)
    if err != nil {
        http.Error(w, "Invalid ID", http.StatusBadRequest)
        return
    }

    entity, err := h.usecase.Get${ENTITY_NAME}Profile(id)
    if err != nil {
        http.Error(w, "Not found", http.StatusNotFound)
        return
    }

    json.NewEncoder(w).Encode(entity)
}
EOL

# Archivo de configuración
cat <<EOL > "$PROJECT_NAME/config/db.go"
package config

import (
    "log"
    "os"
    "github.com/jmoiron/sqlx"
    _ "github.com/lib/pq"
)

func SetupDB() *sqlx.DB {
        conn:=os.Getenv("CONNECTION")
    db, err := sqlx.Connect("postgres", conn)
    if err != nil {
        log.Fatal(err)
    }
    return db
}
EOL

# Archivo config env
cat <<EOL > "$PROJECT_NAME/config/setenv.go"
package config


import "github.com/joho/godotenv"

func Config() {
	err := godotenv.Load("../.env")
	if err != nil {
		_ = godotenv.Load("/go/bin/.env")
	}
}
EOL
# Archivo principal
cat <<EOL > "$PROJECT_NAME/cmd/main.go"
package main

import (
    "log"
    "net/http"
    "${PROJECT_NAME}/config"
    "${PROJECT_NAME}/handler"
    "${PROJECT_NAME}/repository"
    "${PROJECT_NAME}/usecases"
)

func init() {
	config.Config()
}

func main() {
    db := config.SetupDB()
    ${ENTITY_NAME_LOWER}Repo := repository.New${ENTITY_NAME}Repository(db)
    ${ENTITY_NAME_LOWER}Usecase := usecases.New${ENTITY_NAME}Usecase(${ENTITY_NAME_LOWER}Repo)
    ${ENTITY_NAME_LOWER}Handler := handler.New${ENTITY_NAME}Handler(${ENTITY_NAME_LOWER}Usecase)

    http.HandleFunc("/${ENTITY_NAME_LOWER}/register", ${ENTITY_NAME_LOWER}Handler.Register${ENTITY_NAME})
    http.HandleFunc("/${ENTITY_NAME_LOWER}/profile", ${ENTITY_NAME_LOWER}Handler.Get${ENTITY_NAME}Profile)

    log.Fatal(http.ListenAndServe(os.Getenv("PORT"), nil))
}
EOL

echo "Estructura de la API para ${ENTITY_NAME} generada en el proyecto $PROJECT_NAME."

# Archivo Dockerfile
cat <<EOL > "$PROJECT_NAME/Dockerfile"
# Etapa de construcción
FROM golang:alpine AS build

# GOPROXY resolves dependencies treefrom cache or repository
ENV GOPROXY=https://proxy.golang.org

WORKDIR /go/src/api
COPY . .
# Set OS as linux
RUN GOOS=linux go build -o /go/bin/api cmd/main.go

EXPOSE 8080

FROM alpine
COPY --from=build /go/bin/api /go/bin/api
COPY --from=build /go/src/api/.env /go/bin/.env

ENTRYPOINT ["/go/bin/api"]
EOL

echo "Estructura de la API para ${ENTITY_NAME} generada en el proyecto $PROJECT_NAME."



# Crear estructura de carpetas para GitHub Actions
mkdir -p "$PROJECT_NAME/.github/workflows"

# Archivo dev.yml
cat <<EOL > "$PROJECT_NAME/.github/workflows/dev.yml"
name: deploy

on:
  push:
    branches:
      - main

jobs:
  deploy:
    name: deploy cloud run
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v2

      - name: Set up environment
        run: |
          echo "PORT=\${{ secrets.PORT }}" > .env
          echo "CONNECTION=\${{ secrets.CONNECTION_DEV }}" >> .env
          echo "MAIL_PASSWORD=\${{ secrets.MAIL_PASSWORD }}" >> .env
          echo "PSWD_JWT=\${{ secrets.PSWD_JWT}}" >> .env

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: \${{ github.actor }}
          password: \${{ secrets.GITHUB_TOKEN }}

      - name: Build and push to GitHub Packages
        uses: docker/build-push-action@v3
        with:
          context: .
          push: true
          tags: ghcr.io/pigside/${ENTITY_NAME_LOWER}:dev

      - name: SSH and run command
        uses: appleboy/ssh-action@v0.1.3
        with:
          host: \${{ secrets.SSH_HOST }}
          port: \${{ secrets.SSH_PORT }}
          username: \${{ secrets.SSH_USERNAME }}
          password: \${{ secrets.SSH_PASSWORD }}
          script: |
            echo "Conexión SSH exitosa"
            /scriptsv2/deploy_${ENTITY_NAME_LOWER}.sh
EOL

# Archivo test.yml
cat <<EOL > "$PROJECT_NAME/.github/workflows/test.yml"
name: deploy

on:
  push:
    branches:
      - main

jobs:
  deploy:
    name: deploy cloud run
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v2

      - name: Set up environment
        run: |
          echo "PORT=\${{ secrets.PORT }}" > .env
          echo "CONNECTION=\${{ secrets.CONNECTION_TEST }}" >> .env
          echo "MAIL_PASSWORD=\${{ secrets.MAIL_PASSWORD }}" >> .env
          echo "PSWD_JWT=\${{ secrets.PSWD_JWT}}" >> .env

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: \${{ github.actor }}
          password: \${{ secrets.GITHUB_TOKEN }}

      - name: Build and push to GitHub Packages
        uses: docker/build-push-action@v3
        with:
          context: .
          push: true
          tags: ghcr.io/pigside/${ENTITY_NAME_LOWER}:test

      - name: SSH and run command
        uses: appleboy/ssh-action@v0.1.3
        with:
          host: \${{ secrets.SSH_HOST }}
          port: \${{ secrets.SSH_PORT }}
          username: \${{ secrets.SSH_USERNAME }}
          password: \${{ secrets.SSH_PASSWORD }}
          script: |
            echo "Conexión SSH exitosa"
            /scriptsv2/deploy_${ENTITY_NAME_LOWER}.sh
EOL

# Archivo prod.yml
cat <<EOL > "$PROJECT_NAME/.github/workflows/prod.yml"
name: deploy

on:
  push:
    branches:
      - main

jobs:
  deploy:
    name: deploy cloud run
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v2

      - name: Set up environment
        run: |
          echo "PORT=\${{ secrets.PORT }}" > .env
          echo "CONNECTION=\${{ secrets.CONNECTION_PROD }}" >> .env
          echo "MAIL_PASSWORD=\${{ secrets.MAIL_PASSWORD }}" >> .env
          echo "PSWD_JWT=\${{ secrets.PSWD_JWT}}" >> .env
         

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: \${{ github.actor }}
          password: \${{ secrets.GITHUB_TOKEN }}

      - name: Build and push to GitHub Packages
        uses: docker/build-push-action@v3
        with:
          context: .
          push: true
          tags: ghcr.io/pigside/${ENTITY_NAME_LOWER}:prod

      - name: SSH and run command
        uses: appleboy/ssh-action@v0.1.3
        with:
          host: \${{ secrets.SSH_HOST_PROD }}
          port: \${{ secrets.SSH_PORT }}
          username: \${{ secrets.SSH_USERNAME }}
          password: \${{ secrets.SSH_PASSWORD }}
          script: |
            echo "Conexión SSH exitosa"
            /scriptsv2/deploy_${ENTITY_NAME_LOWER}.sh
EOL

echo "Estructura de la API para ${ENTITY_NAME} generada en el proyecto $PROJECT_NAME."