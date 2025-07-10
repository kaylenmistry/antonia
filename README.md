# Antonia

## Contributing

You can ensure your code is compliant with project standards by running `mix check`. This will run all of our code checks and tests.

## 👩‍💻 Development requirements

Some older versions of these might work, but we generally recommend these. Also,
check our [`.tool-versions` file](./.tool-versions) where we specify versions of
the tools so [ASDF] can know which one to use.

- Elixir 1.18.1-otp-27
- Erlang OTP 27.2
- NodeJS 23.6.1
- Docker 20.10
- Docker Compose (with support for spec version 3.9)

## 🏃‍ Run locally

### Dependencies

All project dependencies can be brough up using `docker compose up -d`. This will bring up the following services:

- Postgres (port 5432)

### Running the application

To start the app:

- Bring up project dependencies with `docker-compose up -d`
- Run `mix setup`. This will
  - Fetch the project dependencies (Elixir and Yarn)
  - Create, migrate and seed the database
- Start the server with `mix phx.server`

This will start the application on `localhost:4000`, along with Postgres.

You might also find the following commands useful:

- `iex` - Opens an Interactive Elixir shell
- `iex -S mix` - Opens an Interactive Elixir shell with the compiled project
- `iex -S mix phx.server` - As above, but also starts the web server
