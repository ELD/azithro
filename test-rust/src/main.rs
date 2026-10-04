fn main() {
    println!("Hello, world!");

    println!("{:?}", my_fn(10));

    let _ = MyStruct { id: 3 }.id;
}

fn my_fn(var: i32) -> bool {
    var > 5
}

struct MyStruct {
    id: i32,
}
