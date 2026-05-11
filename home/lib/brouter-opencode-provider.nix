{ }:

{
  # Build an opencode provider config (and matching agent/model wiring) for a
  # brouter-shaped backend. Output is the deep-mergeable shape consumed by
  # opencode.json.
  #
  # Args:
  #   providerName : opencode provider key (e.g. "brouter", "brouter-proxy").
  #   baseURL      : full HTTP URL including the /v1 suffix.
  #   displayName  : human-readable name shown in opencode UI.
  #   defaultModel : model id used by primary agents (default "auto").
  #   fastModel    : model id used by the title agent (default "fast").
  mkProvider =
    {
      providerName,
      baseURL,
      displayName,
      defaultModel ? "auto",
      fastModel ? "fast",
    }:
    let
      mainModel = "${providerName}/${defaultModel}";
      titleModel = "${providerName}/${fastModel}";
    in
    {
      provider.${providerName} = {
        npm = "@ai-sdk/openai-compatible";
        name = displayName;
        options = {
          inherit baseURL;
          apiKey = "brouter";
        };
        models = {
          auto.name = "${displayName} Auto";
          fast.name = "${displayName} Fast";
          strong.name = "${displayName} Strong";
        };
      };
      model = mainModel;
      small_model = titleModel;
      agent = {
        build.model = mainModel;
        plan.model = mainModel;
        explore.model = mainModel;
        general.model = mainModel;
        title.model = titleModel;
        summary.model = mainModel;
        compaction.model = mainModel;
      };
    };
}
