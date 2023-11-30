# llvm

To build for OSX run (on an ARM64 machine):

```
./build.pl
/usr/bin/arch -x86_64 ./build.pl --skip-checkout
cd release/osx
./lipo.pl
```

To build for windows, you need VS 2019 installed including the arm64 cross compiler option.

Only the required targets for the two architectures are included.

```
./build.pl --targetsToBuild="X86;WebAssembly"
./build.pl --targetsToBuild="AArch64;WebAssembly" --skip-checkout --architecture=arm64
```

To build on linux, on machine with cross compilers:

```
./build.pl
./build.pl --skip-checkout --architecture=arm64
./build.pl --skip-checkout --architecture=arm32
```

To build for android, you need to run on a suitable host with Android Studio and the required NDK installed:

```
./build.pl --NDK=(NDK path) --architecture=arm64 --androidVersion=26 —-targetsToBuild=AArch64
```