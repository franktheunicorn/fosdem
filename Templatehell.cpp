// Totally evil example of why C++ template syntax and free-for-all operator

// overloading is a Bad, Bad Idea.

#include <iostream>

struct Bad { };

struct B { };

struct A {

	Bad operator,(B b) { return Bad(); }};

struct D { };

struct Ugly {

	D operator>(Bad b) { return D(); }

} U;

struct Terrible { } T;

struct Evil {

	~Evil() {

		std::cout << "Hard drive reformatted." << std::endl;

	}

};

struct Nasty {

	Evil operator,(D d) { return Evil(); }

};

struct Idea {

	void operator()(A a, B b) {

		std::cout << "Good idea, data saved." << std::endl;

	}

	Nasty operator<(Terrible t) { return Nasty(); }

} gun;

template<typename T, typename U>

void fun(A a, B b) {

	std::cout << "Have fun!" << std::endl;

}

int main() {

	A a;

	B b;

	// What do these lines do?

	fun<A, B>(a, b);

	gun<T, U>(a, b);

}
