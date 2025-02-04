;; Test try-delegate blocks.

(module
  (tag $e0)
  (tag $e1)

  (func (export "delegate-no-throw") (result i32)
    (try $t (result i32)
      (do (try (result i32) (do (i32.const 1)) (delegate $t)))
      (catch $e0 (i32.const 2))
    )
  )

  (func $throw-if (param i32)
    (local.get 0)
    (if (then (throw $e0)) (else))
  )

  (func (export "delegate-throw") (param i32) (result i32)
    (try $t (result i32)
      (do
        (try (result i32)
          (do (local.get 0) (call $throw-if) (i32.const 1))
          (delegate $t)
        )
      )
      (catch $e0 (i32.const 2))
    )
  )

  (func (export "delegate-skip") (result i32)
    (try $t (result i32)
      (do
        (try (result i32)
          (do
            (try (result i32)
              (do (throw $e0) (i32.const 1))
              (delegate $t)
            )
          )
          (catch $e0 (i32.const 2))
        )
      )
      (catch $e0 (i32.const 3))
    )
  )

  (func (export "delegate-to-block") (result i32)
    (try (result i32)
      (do (block (try (do (throw $e0)) (delegate 0)))
          (i32.const 0))
      (catch_all (i32.const 1)))
  )

  (func (export "delegate-to-catch") (result i32)
    (try (result i32)
      (do (try
            (do (throw $e0))
            (catch $e0
              (try (do (rethrow 1)) (delegate 0))))
          (i32.const 0))
      (catch_all (i32.const 1)))
  )

  (func (export "delegate-to-caller")
    (try (do (try (do (throw $e0)) (delegate 1))) (catch_all))
  )

  (func $select-tag (param i32)
    (block (block (block (local.get 0) (br_table 0 1 2)) (return)) (throw $e0))
    (throw $e1)
  )

  (func (export "delegate-merge") (param i32 i32) (result i32)
    (try $t (result i32)
      (do
        (local.get 0)
        (call $select-tag)
        (try
          (result i32)
          (do (local.get 1) (call $select-tag) (i32.const 1))
          (delegate $t)
        )
      )
      (catch $e0 (i32.const 2))
    )
  )

  (func (export "delegate-throw-no-catch") (result i32)
    (try (result i32)
      (do (try (result i32) (do (throw $e0) (i32.const 1)) (delegate 0)))
      (catch $e1 (i32.const 2))
    )
  )
)

(assert_return (invoke "delegate-no-throw") (i32.const 1))

(assert_return (invoke "delegate-throw" (i32.const 0)) (i32.const 1))
(assert_return (invoke "delegate-throw" (i32.const 1)) (i32.const 2))

(assert_exception (invoke "delegate-throw-no-catch"))

(assert_return (invoke "delegate-merge" (i32.const 1) (i32.const 0)) (i32.const 2))
(assert_exception (invoke "delegate-merge" (i32.const 2) (i32.const 0)))
(assert_return (invoke "delegate-merge" (i32.const 0) (i32.const 1)) (i32.const 2))
(assert_exception (invoke "delegate-merge" (i32.const 0) (i32.const 2)))
(assert_return (invoke "delegate-merge" (i32.const 0) (i32.const 0)) (i32.const 1))

(assert_return (invoke "delegate-skip") (i32.const 3))

(assert_return (invoke "delegate-to-block") (i32.const 1))
(assert_return (invoke "delegate-to-catch") (i32.const 1))

(assert_exception (invoke "delegate-to-caller"))

(assert_malformed
  (module quote "(module (func (delegate 0)))")
  "unexpected token"
)

(assert_malformed
  (module quote "(module (tag $e) (func (try (do) (catch $e) (delegate 0))))")
  "unexpected token"
)

(assert_malformed
  (module quote "(module (func (try (do) (catch_all) (delegate 0))))")
  "unexpected token"
)

(assert_malformed
  (module quote "(module (func (try (do) (delegate) (delegate 0))))")
  "unexpected token"
)

(assert_invalid
  (module (func (try (do) (delegate 1))))
  "unknown label"
)
