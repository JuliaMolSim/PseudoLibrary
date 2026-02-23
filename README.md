# PseudoLibrary

Collected pseudopotential files for use as Julia artifacts.

The data in this repository are provided in a convenient fashion
via the [PseudoPotentialData](https://github.com/JuliaMolSim/PseudoPotentialData.jl)
package. Julia users, which want to use pseudopotentials in a calculation
will likely find it more useful to directly employ
[PseudoPotentialData](https://github.com/JuliaMolSim/PseudoPotentialData.jl).
An example showing these pseudopotentials in action with a DFT calculation
(using [DFTK.jl](https://dftk.org)) is given
in the [DFTK documentation](https://docs.dftk.org/stable/examples/pseudopotentials/).

*Note:* This branch is a relatively recent (Dec 2024) rewrite and does not yet contain
all pseudopotentials, which were ones made available here.
For an older version of the library offering a larger set of pseudopotentials,
see the [main branch](https://github.com/JuliaMolSim/PseudoLibrary/tree/main/).


## Available pseudopotentials

The currently available pseudopotential collections can be found in [the pseudos subfolder](/pseudos).
Each collection name starts with a prefix for the pseudopotential family, including quantifiers
such as `sr` (scalar relativistic) or `fr` (full relativistic). Next comes the XC functional
for which the pseudo was constructed (e.g. `pbe`, `lda`, `pbesol`), potentially followed
a version indication, the generating code and some details on the promised accuracy
(stringent, standard, loose).
The name closes in the file format in which the pseudos are stored (e.g. `upf`, `gth`, `psp8`),
which is also the extension used for all file names.

The list of available pseudo families
with links to further resources and the appropriate references:

### [PseudoDojo](http://www.pseudo-dojo.org) (prefixed dojo)
```
M.J. van Setten, M. Giantomassi, E. Bousquet, M.J. Verstraete, D.R. Hamann, X. Gonze, G.-M. Rignanese,
The PseudoDojo: Training and grading a 85 element optimized norm-conserving pseudopotential table,
Computer Physics Communications,
Volume 226,
2018,
https://doi.org/10.1016/j.cpc.2018.01.012.
```

**Script.** The pseudodojo pseudopotentials have been added by running the script
```sh
julia --project=scripts scripts/add_pseudodojo.jl pseudos
```

**Collection-specific metadata.** Contains the following element-specific metadata:
* `cutoffs_normal`, `cutoffs_high`, `cutoffs_low`: Respective recommended cutoffs by PseudoDojo
* `rcut`: Recommended radial cutoff when integrating numeric pseudopotentials (in Bohrs).
   Right now just `5.99` for each element (equal the ABINIT hard-coded value,
   with respect to which PseudoDojo is developed and tested).
   This may be refined in future versions of the library.

### [CP2K GTH-type potentials](https://github.com/cp2k/cp2k-data/tree/master/potentials/Goedecker) (prefixed cp2k)

```
C. Hartwigsen, S. Goedecker, J. Hutter,
Relativistic separable dual-space Gaussian pseudopotentials from H to Rn,
Physical Review B,
Volume 58,
1998,
https://doi.org/10.1103/PhysRevB.58.3641
```

```
S. Goedecker, M. Teter, J. Hutter,
Separable dual-space Gaussian pseudopotentials,
Physical Review B,
Volume 54,
1996,
https://doi.org/10.1103/PhysRevB.54.1703
```

**Script.** The cp2k pseudopotentials have been added by running the script
```sh
julia --project=scripts scripts/add_cp2k.jl pseudos
```
In running the script we categorised the pseudopotential files
into *smallcore*, *semicore* and *largecore*. The mapping from the original filenames
[used upstream](https://github.com/cp2k/cp2k-data/tree/master/potentials/Goedecker/cp2k)
is available in 
[pseudos/cp2k.nc.sr.lda.v0_1.md](pseudos/cp2k.nc.sr.lda.v0_1.md)
and
[pseudos/cp2k.nc.sr.pbe.v0_1.md](pseudos/cp2k.nc.sr.pbe.v0_1.md).

**Collection-specific metadata.** Contains the following element-specific metadata:
* `n_valence_electrons`: Number of valence electrons
* `cp2k_filename`: The original file name used in the CP2K pseudopotential data repository.

## Structure of the Artifact.toml
Next to the usual entries to make the `Artifact.toml` useful to download
peudopotential information as a lazy artifact (using `LazyArtifacts`)
the `Artifact.toml` contains a rich set of metadata for each pseudopotential
family in form of a dictionary with the following keys:

- All keys of the `meta.toml` of the pseudopotential family as discussed below
  (e.g. `collection`, `relativistic`, `version`, `functional`, ...)
- `pseudolibrary_version`: The release version of `PseudoLibrary`

## Structure of the tarballs
- For each element a `element.extension` file (e.g. `Si.upf` or `Al.xml`)
- Optionally, of each element an `element.toml` file as described below,
  which typically contains additional per-element information such as
  `Ecut`, `supersampling`, `n_valence` etc.

## Maintenance tasks
### Adding a new pseudo family
- Add a folder with the pseudopotential files named as `element.extension`
  (e.g. `Si.upf` or `Al.xml`)
- Add a file `meta.toml` into the folder. This file should represent a dictionary
  with the following keys:
  * `collection`: The larger pseudopotential collection (e.g. `dojo` for pseudodojo)
  * `relativistic`: The model of relativistic effects used (e.g. `sr` or `fr`)
  * `version`: The version of this collection of pseudopotentials (e.g. `version`)
  * `type`: Pseudopotential type, such as `nc`, `paw`, `us`
  * `functional` such as `lda`, `pbe`, `pbesol`
  * `extension`: The file extension of all files
  * `program`: Code used to generate the pseudopotentials
  * `extra`: List of some extra identifiers (e.g. `semicore` or `standard`)
- For each element you can add an `element.toml` file with additional metadata
  about this pseudopotential. Collection-specific fields are explained
  above in the *Available pseudopotentials* section. Common fields
  available for most pseudopotential collections include:
  * `Ecut`: A recommended kinetic energy cutoff value for the wavefunction
    to be employed with this pseudopotential.
    Note, that some libraries set this to `-1` to indicate *unknown*.
  * `supersamping`: A recommended supersampling to employ to make up the
    FFT grid used for densities and potentials. Many codes use the concept
    of a *density cutoff* instead of supersampling.
    The formula to convert between the two conventions is
    `Ecut_density = supersampling * supersampling * Ecut`, i.e. the square
    of the supersampling factor times the `Ecut` value above gives the
    density cutoff.

Note, that for most already existing
pseudopotential collections scripts have been employed to simplify the addition
of new families. These are indicated in the *Available Pseudopotentials*
section above.

### Releasing a new version
- Update the `LIBRARY_VERSION` variable in `scripts/make_artifacts.jl`
- Make a tag of the form `v0.0.0` and push the tag
- The CI will effectively call
  ```sh
  julia --project=scripts scripts/make_artifact.jl pseudos output
  ```
  to assemble a `Artifact.toml` and pack
  respective tarballs, which will then be made available as assets to this new release.
- Update the `Artifact.toml` in [PseudoPotentialData](https://github.com/JuliaMolSim/PseudoPotentialData.jl)
  and release a new version over there.
