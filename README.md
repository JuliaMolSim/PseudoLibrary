# Collected pseudopotential files for use as Julia artefacts

## Using these files in your project / calculation
If you want to use these artefacts in your calculation to automatically retrieve
the required pseudopotentials, follow these instructions. An example showing these
pseudopotentials in action with a DFT calculation (using [DFTK.jl](https://dftk.org))
is given in the [DFTK documentation](https://docs.dftk.org/stable/examples/pseudopotentials/).
If you know how artefacts work in Julia skip to the next section.

1. Make sure you are using a local project environment (or you are within a package environment).
   If you don't know what either of this is, see the Pkg.jl documentation on
   [working with environments](https://pkgdocs.julialang.org/v1/environments/).

2. Install the `LazyArtifacts` package into the local environment. Note down the location
   of your `Project.toml`.

3. Download the [Artifacts.toml](https://raw.github.com/JuliaMolSim/PseudoLibrary/main/Artifacts.toml)
   of this repository and put it in the same folder as your `Project.toml`.

4. Select the pseudopotential you want to use. E.g. the silicon pseudopotential of the
   `pd_nc_sr_pbe_stringent_0.4.1_upf` pseudopotential collection (more on what this means below).

5. To use this file in a script / calculation employ the following code:
   ```julia
   using LazyArtifacts

   # ... other code and things

   pseudofile = artifact"pd_nc_sr_pbe_stringent_0.4.1_upf/Si.upf"

   # Use pseudofile as full path to the UPF file with the pseudo definition.
   ```
   This will now automatically download the pseudopotential file from this
   repository and directly put the full path to the downloaded pseudopotential
   file into the `pseudofile` variable, e.g. a string such as
   `/home/user/.julia/artifacts/56094b8162385233890d523c827ba06e07566079/Si.upf`,
   which luckily you don't usually have to know or remember. Note further
   that this path may differ between computers, julia versions etc., so it
   is highly recommended to use the `artifact" ... "` way of specifying the
   file instead of the expanded path.

## Currently available pseudopotentials
The currently available pseudopotential collections can be found in [the pseudos subfolder](/pseudos).
Each collection name starts with a prefix for the pseudopotential family, including quantifiers
such as `sr` (scalar relativistic) or `fr` (full relativistic). Next comes the XC functional
for which the pseudo was constructed (e.g. `pbe`, `lda`, `pbesol`), potentially followed
by some details on the promised accuracy (strigent, standard, loose) or a version indication.
The name closes in the file format in which the pseudos are stored (e.g. `upf`, `hgh`, `psp8`),
which is also the extension used for all file names.

The list of available pseudo families
with links to further resources and the appropriate references:

### [GBRV](https://www.physics.rutgers.edu/gbrv/) (prefixed gbrv_)
```
Kevin F. Garrity, Joseph W. Bennett, Karin M. Rabe, David Vanderbilt,
Pseudopotentials for high-throughput DFT calculations,
Computational Materials Science,
Volume 81,
2014,
https://doi.org/10.1016/j.commatsci.2013.08.053.
```

### [HGH](http://pseudopotentials.quantum-espresso.org/legacy_tables/hartwigesen-goedecker-hutter-pp) (prefixed hgh_)

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

### [PseudoDojo](http://www.pseudo-dojo.org) (prefixed pd_)

```
M.J. van Setten, M. Giantomassi, E. Bousquet, M.J. Verstraete, D.R. Hamann, X. Gonze, G.-M. Rignanese,
The PseudoDojo: Training and grading a 85 element optimized norm-conserving pseudopotential table,
Computer Physics Communications,
Volume 226,
2018,
https://doi.org/10.1016/j.cpc.2018.01.012.
```

### [SG15](http://quantum-simulation.org/potentials/sg15_oncv/) (prefixed sg15_)

```
M. Schlipf, F. Gygi,
Optimization algorithm for the generation of ONCV pseudopotentials,
Computer Physics Communications,
Volume 196,
2015,
https://doi.org/10.1016/j.cpc.2015.05.011.
```

```
P. Scherpelz, M. Govoni, I. Hamada, G. Galli,
Implementation and Validation of Fully Relativistic GW Calculations: Spin–Orbit Coupling in Molecules, Nanocrystals, and Solids,
Journal of Chemical Theory and Computation,
Volume 12,
2016,
https://doi.org/10.1021/acs.jctc.6b00114
```

### [SSSP](https://www.materialscloud.org/discover/sssp/table/precision) (prefixed sssp_)

```
G. Prandini, A. Marrazzo, I.E. Castelli, N. Mounet, N. Marzari,
Precision and efficiency in solid-state pseudopotential calculations,
npj Computational Materials,
Volume 4,
2018,
https://doi.org/10.1038/s41524-018-0127-2
```
