all: double_speed.gb double_speed_ly.gb

double_speed.o: double_speed.s common/*
	wla-gb -o double_speed.o double_speed.s

double_speed.gb: double_speed.o linkfile
	wlalink linkfile double_speed.gb

double_speed_ly.o: double_speed_ly.s common/*
	wla-gb -o double_speed_ly.o double_speed_ly.s

double_speed_ly.gb: double_speed_ly.o linkfile
	wlalink linkfile double_speed_ly.gb

clean:
	rm *.o *.gb
