{ lib, pkgs, cfg }:
let
  inherit (lib)
    concatMapAttrs
    concatMapStringsSep
    concatStringsSep
    drop
    filterAttrs
    filter
    flatten
    hasPrefix
    mapAttrsToList
    optional
    splitString
    unique;

  enabledAgents = filterAttrs (_: agent: agent.enable) cfg.agents;

  enabledSkillForAgent = agentName: skill:
    let
      override = skill.agents.${agentName} or { };
      overrideEnable = override.enable or null;
    in
    skill.enable && (if overrideEnable == null then true else overrideEnable);

  sourcePath = skill:
    if skill.source == null then null
    else if skill.source.github != null then
      let
        repo = pkgs.fetchFromGitHub {
          inherit (skill.source.github) owner repo rev;
          sha256 = skill.source.github.hash;
        };
      in
      "${repo}/${skill.source.github.path}"
    else if skill.source.file != null then
      pkgs.fetchurl
        {
          inherit (skill.source.file) url;
          sha256 = skill.source.file.hash;
        }
    else
      builtins.throw "programs.aiAgents.skills source for ${skill.source.library}#${skill.source.skillName} must define github or file";

  sourceSkillFile = skill:
    let
      path = sourcePath skill;
    in
    if path != null && builtins.pathExists "${path}/SKILL.md"
    then "${path}/SKILL.md"
    else path;

  sourceSkillDir = skill:
    let
      path = sourcePath skill;
    in
    if path != null && builtins.pathExists "${path}/SKILL.md"
    then path
    else null;

  skillBody = skill:
    if skill.body != null then skill.body
    else
      let
        file = sourceSkillFile skill;
      in
      if file != null
      then builtins.readFile file
      else builtins.throw "programs.aiAgents.skills entry must define either body or source";

  stripFrontmatter = text:
    if hasPrefix "---\n" text then
      concatStringsSep "---\n" (drop 2 (splitString "---\n" text))
    else
      text;

  skillText = agentName: skillName:
    let
      skill = cfg.skills.${skillName};
      override = skill.agents.${agentName} or { };
      bodyAppend = override.bodyAppend or "";
      description =
        if (override.description or null) != null
        then override.description
        else skill.description;
      frontmatter = ''
        ---
        name: ${builtins.toJSON skillName}
        description: ${builtins.toJSON description}
        ---

      '';
    in
    frontmatter + stripFrontmatter (skillBody skill) + (if bodyAppend != "" then "\n${bodyAppend}" else "");

  skillSource = agentName: skillName:
    let
      skill = cfg.skills.${skillName};
      renderedSkill = pkgs.writeText "SKILL.md" (skillText agentName skillName);
      dir = sourceSkillDir skill;
    in
    if dir != null then
      pkgs.runCommand "ai-agent-skill-${skillName}" { } ''
        mkdir -p "$out"
        cp -R ${dir}/. "$out/"
        chmod -R u+w "$out"
        install -m 0644 ${renderedSkill} "$out/SKILL.md"
      ''
    else
      pkgs.writeTextDir "SKILL.md" (skillText agentName skillName);

  agentSkillNames = agent:
    unique (cfg.defaultSkillSet ++ agent.skillNames);

  mkSkillFilesForAgent = agentName: agent:
    concatMapAttrs
      (skillName: skill:
        if enabledSkillForAgent agentName skill then {
          "${agent.skillDir}/${skillName}" = {
            force = true;
            source = skillSource agentName skillName;
          };
        } else { })
      (filterAttrs (skillName: _: builtins.elem skillName (agentSkillNames agent)) cfg.skills);

  skillPackagesForAgent = agentName: agent:
    flatten (map
      (skillName:
        let
          skill = cfg.skills.${skillName} or null;
          override = if skill == null then { } else skill.agents.${agentName} or { };
        in
        if skill != null && enabledSkillForAgent agentName skill
        then skill.packages ++ (override.packages or [ ])
        else [ ])
      (agentSkillNames agent));

  skillDirsForAgent = agentName: agent:
    map
      (skillName: "${agent.skillDir}/${skillName}")
      (filter
        (skillName:
          let
            skill = cfg.skills.${skillName} or null;
          in
          skill != null && enabledSkillForAgent agentName skill)
        (agentSkillNames agent));

  managedSkillDirs = flatten (mapAttrsToList skillDirsForAgent enabledAgents);
in
{
  homePackages =
    unique
      (flatten
        (mapAttrsToList
          (agentName: agent:
            (optional (agent.package != null) agent.package)
            ++ agent.packages
            ++ skillPackagesForAgent agentName agent)
          enabledAgents));

  homeFiles = concatMapAttrs mkSkillFilesForAgent enabledAgents;

  skillDirMigration = concatMapStringsSep "\n"
    (relativePath: ''
      target="$HOME/${relativePath}"
      if [ -d "$target" ] && [ ! -L "$target" ] && [ -L "$target/SKILL.md" ]; then
        if ! ${pkgs.findutils}/bin/find "$target" -mindepth 1 -maxdepth 1 ! -name SKILL.md -print -quit | ${pkgs.gnugrep}/bin/grep -q .; then
          ${pkgs.coreutils}/bin/rm -f "$target/SKILL.md"
          ${pkgs.coreutils}/bin/rmdir "$target"
        fi
      fi
    '')
    managedSkillDirs;
}
