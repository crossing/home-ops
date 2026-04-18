{ ... }:
{
  programs.claude-code.enable = true;
  programs.claude-wrapper = {
    enable = true;
    models = {
      opus = "nvidia/nemotron-3-super-120b-a12b:free";
      sonnet = "nvidia/nemotron-3-super-120b-a12b:free";
      haiku = "nvidia/nemotron-3-super-120b-a12b:free";
      subagent = "nvidia/nemotron-3-super-120b-a12b:free";
    };
  };
}
