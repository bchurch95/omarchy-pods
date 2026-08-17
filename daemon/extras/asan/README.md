# ASAN+UBSAN sanitizer build

Parallel build dir that compiles every test under AddressSanitizer +
UndefinedBehaviorSanitizer. Catches memory bugs the GCC RelWithDebInfo
build can't see — out-of-bounds reads/writes, use-after-free,
integer overflow, signed/unsigned conversion underflow, vptr corruption.

## Configure + build

```bash
cd linux
cmake -S . -B build-asan \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DBUILD_TESTING=ON \
    -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer -g -O1" \
    -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address,undefined"
cmake --build build-asan -j
```

## Run

```bash
cd linux/build-asan
ASAN_OPTIONS="detect_leaks=0:halt_on_error=1" \
UBSAN_OPTIONS="halt_on_error=1:print_stacktrace=1" \
    ctest --output-on-failure --timeout 60
```

`detect_leaks=0` because Qt's QObject machinery leaks at shutdown by
design (static plugin metatypes etc); flip to `=1` if you're chasing
a specific leak.

## When to run

Loop category `w` ticks. Re-run quarterly even without changes —
sanitizers find regressions in deps (Qt6, OpenSSL) on update.

## Last clean pass

See RELIABILITY.md "Last ASAN+UBSAN pass" row.
