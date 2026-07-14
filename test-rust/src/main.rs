fn main() {
    println!("Hello, world!");

    let _ = MyStruct { id: 3 }.id;
}

struct MyStruct {
    id: i32,
}
