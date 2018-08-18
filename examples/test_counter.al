import counter
import test

// Test a counter that has not reached zero.
proc test_counter_not_zero {
    let c = Counter "123"
    ctr_start c
    ctr_dec c
    ctr_dec c

    let r = ""
    ctr_is_zero c r

    assert_tape_eq r "0" "counter_not_zero"
}
test_counter_not_zero

// Test a counter that has reached zero.
proc test_counter_zero {
    let c = Counter "123"
    ctr_start c
    ctr_dec c
    ctr_dec c
    ctr_dec c

    let r = ""
    ctr_is_zero c r

    assert_tape_eq r "1" "counter_zero_zero"
}
test_counter_zero

// Tests a counter that has reached zero can be reused.
proc test_counter_reuse {
    let c = Counter "123"
    ctr_start c
    ctr_dec c
    ctr_dec c
    ctr_dec c

    ctr_start c

    let r = ""
    ctr_is_zero c r

    assert_tape_eq r "0" "counter_reuse"
}
test_counter_reuse
