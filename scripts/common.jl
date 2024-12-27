KNOWN_FUNCTIONALS = ["pbe", "lda", "pbesol"]
KNOWN_EXTENSIONS  = ["xml", "upf", "hgh", "psp8"]

function check_valid_meta(meta::AbstractDict, folder="")
    needed_keys = ("collection", "type", "relativistic", "functional",
                   "version", "program", "extra", "extension")
    for k in needed_keys
        if !(k in keys(meta))
            error("Required key $k not found in metadata (in $folder)")
        end
    end

    if !(meta["type"] in ("nc", "paw", "us"))
        error("Invalid type: $(meta["type"]) (in $folder)")
    end
    if !(meta["relativistic"] in ("sr", "fr"))
        error("Invalid relativistic: $(meta["relativistic"]) (in $folder)")
    end
    if !(meta["functional"] in KNOWN_FUNCTIONALS)
        error("Unusual functional: $(meta["functional"]) (in $folder)")
    end
    if !(meta["extension"] in KNOWN_EXTENSIONS)
        error("Unusual extension: $(meta["extension"]) (in $folder)")
    end
end

function artifact_name(meta::AbstractDict)
    join((meta["collection"], meta["type"], meta["relativistic"],
          meta["functional"], "v" * replace(meta["version"], "." => "_"),
          join(meta["extra"], "."), meta["extension"]), ".")
end
