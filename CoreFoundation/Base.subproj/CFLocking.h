/*	CFLocking.h
	Copyright (c) 1998-2018, Apple Inc. and the Swift project authors

	Portions Copyright (c) 2014-2018, Apple Inc. and the Swift project authors
	Licensed under Apache License v2.0 with Runtime Library Exception
	See http://swift.org/LICENSE.txt for license information
	See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
*/

/*
        NOT TO BE USED OUTSIDE CF!
*/

#if !defined(__COREFOUNDATION_CFLOCKING_H__)
#define __COREFOUNDATION_CFLOCKING_H__ 1

#if __has_include(<CoreFoundation/TargetConditionals.h>)
#include <CoreFoundation/TargetConditionals.h>
#else
#include <TargetConditionals.h>
#endif

#if __has_include(<pthread.h>)
#include <pthread.h>
#endif

#if TARGET_OS_MAC

#include <pthread.h>

typedef pthread_mutex_t CFLock_t;

#define CFLockInit ((pthread_mutex_t)PTHREAD_ERRORCHECK_MUTEX_INITIALIZER)
#define CF_LOCK_INIT_FOR_STRUCTS(X) (X = CFLockInit)

#define __CFLock(LP) ({ (void)pthread_mutex_lock(LP); })

#define __CFUnlock(LP) ({ (void)pthread_mutex_unlock(LP); })

#define __CFLockTry(LP) ({ pthread_mutex_trylock(LP) == 0; })

// SPI to permit initialization of values in Swift
static inline CFLock_t __CFLockInit(void) { return CFLockInit; }

#elif TARGET_OS_WIN32

#define NOMINMAX
#define VC_EXTRALEAN
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#include <synchapi.h>

typedef int32_t CFLock_t;
#define CFLockInit 0
#define CF_LOCK_INIT_FOR_STRUCTS(X) (X = CFLockInit)

CF_INLINE void __CFLock(volatile CFLock_t *lock) {
  while (InterlockedCompareExchange((long volatile *)lock, ~0, 0) != 0) {
    Sleep(0);
  }
}

CF_INLINE void __CFUnlock(volatile CFLock_t *lock) {
  MemoryBarrier();
  *lock = 0;
}

CF_INLINE Boolean __CFLockTry(volatile CFLock_t *lock) {
  return (InterlockedCompareExchange((long volatile *)lock, ~0, 0) == 0);
}

// SPI to permit initialization of values in Swift
static inline CFLock_t __CFLockInit(void) { return CFLockInit; }

#elif TARGET_OS_LINUX || TARGET_OS_BSD

#include <stdint.h>
#include <unistd.h>

typedef int32_t CFLock_t;
#define CFLockInit 0
#define CF_LOCK_INIT_FOR_STRUCTS(X) (X = CFLockInit)

CF_INLINE void __CFLock(volatile CFLock_t *lock) {
  while (__sync_val_compare_and_swap(lock, 0, ~0) != 0) {
    sleep(0);
  }
}

CF_INLINE void __CFUnlock(volatile CFLock_t *lock) {
  __sync_synchronize();
  *lock = 0;
}

CF_INLINE Boolean __CFLockTry(volatile CFLock_t *lock) {
  return (__sync_val_compare_and_swap(lock, 0, ~0) == 0);
}

// SPI to permit initialization of values in Swift
static inline CFLock_t __CFLockInit(void) { return CFLockInit; }

typedef CFLock_t OSSpinLock;
#define OS_SPINLOCK_INIT CFLockInit
#define OSSpinLockLock(lock) __CFLock(lock)
#define OSSpinLockUnlock(lock) __CFUnlock(lock)

#elif TARGET_OS_WASI

// Empty shims until https://bugs.swift.org/browse/SR-12097 is resolved.
typedef int32_t CFLock_t;
typedef CFLock_t OSSpinLock;
#define CFLockInit 0
#define CF_LOCK_INIT_FOR_STRUCTS(X) (X = CFLockInit)
#define OS_SPINLOCK_INIT CFLockInit

#define OSSpinLockLock(lock) __CFLock(lock)
#define OSSpinLockUnlock(lock) __CFUnlock(lock)
#define __CFLock(A)     do {} while (0)
#define __CFUnlock(A)   do {} while (0)

static inline CFLock_t __CFLockInit(void) { return CFLockInit; }

#else

#warning CF locks not defined for this platform -- CF is not thread-safe
#define __CFLock(A)     do {} while (0)
#define __CFUnlock(A)   do {} while (0)

#endif

#if __has_include(<os/lock.h>)
    #include <os/lock.h>
    #if __has_include(<os/lock_private.h>)
        #include <os/lock_private.h>
        #define _CF_HAS_OS_UNFAIR_RECURSIVE_LOCK 1
    #else
        #define os_unfair_lock_lock_with_options(lock, options) os_unfair_lock_lock(lock)
        #define OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION (0)
    #endif
#else
    #define OS_UNFAIR_LOCK_INIT CFLockInit
    #define os_unfair_lock CFLock_t
    #define os_unfair_lock_lock __CFLock
    #define os_unfair_lock_unlock __CFUnlock
    #define os_unfair_lock_lock_with_options(lock, options) __CFLock(lock)
    #define OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION
#endif // __has_include(<os/lock.h>)

#if defined(_CF_HAS_OS_UNFAIR_RECURSIVE_LOCK)
    #undef _CF_HAS_OS_UNFAIR_RECURSIVE_LOCK // Nothing to do here.
    #define _CFPerformDynamicInitOfOSRecursiveLock(lock) do {} while (0)
#else
    #define os_unfair_recursive_lock _CFRecursiveMutex
    #define OS_UNFAIR_RECURSIVE_LOCK_INIT { 0 }
    #define _CFPerformDynamicInitOfOSRecursiveLock _CFRecursiveMutexCreate
    #define os_unfair_recursive_lock_lock _CFRecursiveMutexLock
    #define os_unfair_recursive_lock_lock_with_options(lock, more) _CFRecursiveMutexLock(lock)
    #define os_unfair_recursive_lock_unlock _CFRecursiveMutexUnlock
#endif


#if _POSIX_THREADS
typedef pthread_mutex_t _CFMutex;
#define _CF_MUTEX_STATIC_INITIALIZER PTHREAD_MUTEX_INITIALIZER
CF_INLINE int _CFMutexCreate(_CFMutex *lock) {
  return pthread_mutex_init(lock, NULL);
}
CF_INLINE int _CFMutexDestroy(_CFMutex *lock) {
  return pthread_mutex_destroy(lock);
}
CF_INLINE int _CFMutexLock(_CFMutex *lock) {
  return pthread_mutex_lock(lock);
}
CF_INLINE int _CFMutexUnlock(_CFMutex *lock) {
  return pthread_mutex_unlock(lock);
}

typedef pthread_mutex_t _CFRecursiveMutex;
CF_INLINE int _CFRecursiveMutexCreate(_CFRecursiveMutex *mutex) {
  pthread_mutexattr_t attr;
  pthread_mutexattr_init(&attr);
  pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);

  int result = pthread_mutex_init(mutex, &attr);

  pthread_mutexattr_destroy(&attr);

  return result;
}
CF_INLINE int _CFRecursiveMutexDestroy(_CFRecursiveMutex *mutex) {
  return pthread_mutex_destroy(mutex);
}
CF_INLINE int _CFRecursiveMutexLock(_CFRecursiveMutex *mutex) {
  return pthread_mutex_lock(mutex);
}
CF_INLINE int _CFRecursiveMutexUnlock(_CFRecursiveMutex *mutex) {
  return pthread_mutex_unlock(mutex);
}
#elif defined(_WIN32)
typedef SRWLOCK _CFMutex;
#define _CF_MUTEX_STATIC_INITIALIZER SRWLOCK_INIT
CF_INLINE int _CFMutexCreate(_CFMutex *lock) {
  InitializeSRWLock(lock);
  return 0;
}
CF_INLINE int _CFMutexDestroy(_CFMutex *lock) {
  (void)lock;
  return 0;
}
CF_INLINE int _CFMutexLock(_CFMutex *lock) {
  AcquireSRWLockExclusive(lock);
  return 0;
}
CF_INLINE int _CFMutexUnlock(_CFMutex *lock) {
  ReleaseSRWLockExclusive(lock);
  return 0;
}

typedef CRITICAL_SECTION _CFRecursiveMutex;
CF_INLINE int _CFRecursiveMutexCreate(_CFRecursiveMutex *mutex) {
  InitializeCriticalSection(mutex);
  return 0;
}
CF_INLINE int _CFRecursiveMutexDestroy(_CFRecursiveMutex *mutex) {
  DeleteCriticalSection(mutex);
  return 0;
}
CF_INLINE int _CFRecursiveMutexLock(_CFRecursiveMutex *mutex) {
  EnterCriticalSection(mutex);
  return 0;
}
CF_INLINE int _CFRecursiveMutexUnlock(_CFRecursiveMutex *mutex) {
  LeaveCriticalSection(mutex);
  return 0;
}
#else
#error "do not know how to define mutex and recursive mutex for this OS"
#endif

#endif // __COREFOUNDATION_CFLOCKING_H__

