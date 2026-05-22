snake: snake.o
	gcc -o snake snake.o

snake.o: snake.asm
	nasm -f elf64 -o snake.o snake.asm
