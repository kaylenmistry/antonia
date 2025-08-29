%Doctor.Config{
  ignore_modules: [
    AntoniaApp,
    AntoniaWeb,
    AntoniaWeb.Telemetry,
    AntoniaWeb.Router,
    AntoniaWeb.Endpoint
  ],
  ignore_paths: [
    ~r/lib\/Antonia_web\/controllers/,
    ~r/lib\/Antonia_web\/live/
  ]
}
