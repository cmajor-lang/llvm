# Cmajor LLVM library builds

This repository contains pre-built libraries for LLVM for use with the Cmajor repository. The repository does not itself contain the LLVM source, just the built libraries and associated headers for each supported platform.

The builds were generated using the `build.pl` script included in this repository. Different platforms have different LLVM target requirements, depending on which targets are marked as supported by the associated Cmajor LLVM module.

## Host build instructions

### MacOS

To build for OSX run (on an ARM64 machine), we build both the x64 and arm64 versions, then use `lipo` to merge the library files to create universal libraries:

```
> ./build.pl /usr/bin/arch -x86_64
> ./build.pl --skip-checkout
> cd release/osx
> ./lipo.pl
```

### Windows

To build for windows, you need VS 2019 installed including the arm64 cross compiler option.

Only the required targets for the two architectures are included.

```
> ./build.pl --targetsToBuild="X86;WebAssembly"
> ./build.pl --targetsToBuild="AArch64;WebAssembly" --skip-checkout --architecture=arm64
```

### Linux

To build on linux for x64, arm64 or arm32 run:

```
> ./build.pl
```

To build on a host with suitable cross compilers:

```
> ./build.pl
> ./build.pl --skip-checkout --architecture=arm64
> ./build.pl --skip-checkout --architecture=arm32
```

### Android

To build for android, you need to run on a suitable host with Android Studio and the required NDK installed:

```
> ./build.pl --NDK=(NDK path) --architecture=arm64 --androidVersion=26 —-targetsToBuild=AArch64
```