#######################################################################
# Generic make script for compiling erlang code                       #
# The environment variable $ERLHOME has to be set to where erlang/OTP #
# is installed                                                        #
# Compiles the code into a ebin dir. relative to the source dir.      #
####################################################################### 
#Compiles the code into a ebin dir. relative to the source dir. 
include vsn.mk

ERLC    := erlc
ERL     := erl
GEN     := beam

EFLAGS := +debug_info
INCLUDE := include
EBIN    := ebin
SRC     := $(wildcard src/*.erl)
HEADERS := $(wildcard $(INCLUDE)/*.hrl)
CODE    := $(patsubst src/%.erl, ebin/%.beam, $(SRC))
DOT_REL_SRC  := $(wildcard ./*.rel.src)
DOT_APP_SRC  := $(wildcard src/*.app.src)
DOTAPP  := $(patsubst src/%.app.src, ebin/%.app, $(DOT_APP_SRC))
DOTREL  := $(patsubst ./%.rel.src, ./%.rel, $(DOT_REL_SRC))
RELBASE := $(notdir $(basename $(DOTREL)))


.PHONY: clean all test

$(EBIN)/%.beam: src/%.erl
	$(ERLC) -I$(INCLUDE)  -W -b beam -o $(EBIN) $(EFLAGS) $(WAIT) $<

all: $(CODE) $(DOTAPP) $(DOTREL) 

$(DOTAPP): $(DOT_APP_SRC)
	echo "created $(DOTAPP)"
	@sed 's/%VSN%/$(VSN)/g' <$(DOT_APP_SRC) >$(DOTAPP)

test: $(CODE) $(DOTAPP)
	export ERL_LIBS=. && erl -noshell -s sud_tests test -s init stop

clean:
	rm -f $(EBIN)/* 

