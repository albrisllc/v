import json2 as json
import math.big
import time

struct MyString implements json.StringDecoder, json.NumberDecoder, json.BooleanDecoder, json.NullDecoder {
mut:
	data string
}

pub fn (mut ms MyString) from_json_string(raw_string string) ! {
	ms.data = raw_string
}

pub fn (mut ms MyString) from_json_number(raw_number string) ! {
	mut first := true

	for digit in raw_number {
		if first {
			first = false
		} else {
			ms.data += '-'
		}

		ms.data += match digit {
			`-` { 'minus' }
			`.` { 'dot' }
			`e`, `E` { 'e' }
			`0` { 'zero' }
			`1` { 'one' }
			`2` { 'two' }
			`3` { 'three' }
			`4` { 'four' }
			`5` { 'five' }
			`6` { 'six' }
			`7` { 'seven' }
			`8` { 'eight' }
			`9` { 'nine' }
			else { 'none' }
		}
	}
}

pub fn (mut ms MyString) from_json_boolean(boolean_value bool) {
	ms.data = if boolean_value { 'yes' } else { 'no' }
}

pub fn (mut ms MyString) from_json_null() {
	ms.data = 'default value'
}

struct NoCustom {
	a int
	b string
}

type MyString2 = string

pub fn (mut ms MyString2) from_json_string(raw_string string) ! {
	ms = raw_string.replace('-', '')
}

fn test_custom() {
	assert json.decode[NoCustom]('{"a": 99, "b": "hi"}')! == NoCustom{
		a: 99
		b: 'hi'
	}

	assert json.decode[[]MyString]('["hi", -9.8e7, true, null]')! == [
		MyString{
			data: 'hi'
		},
		MyString{
			data: 'minus-nine-dot-eight-e-seven'
		},
		MyString{
			data: 'yes'
		},
		MyString{
			data: 'default value'
		},
	]
}

fn test_null() {
	assert json.decode[json.Any]('null]')! == json.Any(json.null)
	assert json.decode[json.Any]('{"hi": 90, "bye": ["lol", -1, null]}')!.str() == '{"bye":["lol",-1,null],"hi":90}'
}

fn test_big() {
	assert json.decode[big.Integer]('0')!.str() == '0'

	assert json.decode[big.Integer]('12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890')!.str() == '12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890'

	assert json.decode[big.Integer]('-12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890')!.str() == '-12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890'
}

fn test_alias() {
	assert json.decode[MyString2]('"h-e---l-lo"')! == 'hello'
}

// Cents is a scalar type: json2 skips its only field, and it is decoded from numbers.
struct Cents {
mut:
	value i64 @[json: '-']
}

fn (mut c Cents) from_json_number(raw string) ! {
	c.value = raw.i64()
}

fn (c Cents) to_json() string {
	return c.value.str()
}

struct CentsHolder {
	c Cents
}

fn test_strict_rejects_kinds_without_a_custom_decoder_for_scalar_types() {
	assert json.decode[CentsHolder]('{"c":12}', strict: true)!.c.value == 12
	for src in ['{"c":{}}', '{"c":{"value":5}}', '{"c":null}', '{"c":[1]}', '{"c":"12"}'] {
		json.decode[CentsHolder](src, strict: true) or {
			assert err.msg().contains('Expected number, but got ')
			continue
		}
		assert false, 'strict decoding of `${src}` should have failed'
	}
	// Outside strict mode an object still decodes into the fields that json2 does not skip.
	assert json.decode[CentsHolder]('{"c":{"value":5}}')!.c.value == 0
}

struct NullHook {
mut:
	a int
}

fn (mut n NullHook) from_json_null() {
	n.a = -1
}

struct NullHookHolder {
	n NullHook
}

struct StringOrObject {
mut:
	name string
}

fn (mut s StringOrObject) from_json_string(raw string) ! {
	s.name = raw
}

struct Stamped {
	time.Time
	note string
}

fn test_strict_keeps_object_forms_of_custom_decoder_types() {
	// These types have fields that json2 decodes, so an object is one of their forms.
	assert json.decode[NullHookHolder]('{"n":{"a":1}}', strict: true)!.n.a == 1
	assert json.decode[NullHookHolder]('{"n":null}', strict: true)!.n.a == -1
	assert json.decode[StringOrObject]('{"name":"n"}', strict: true)!.name == 'n'
	assert json.decode[StringOrObject]('"s"', strict: true)!.name == 's'
	assert json.decode[Stamped]('{"note":"x"}', strict: true)!.note == 'x'
	assert json.decode[json.Null]('{}', strict: true)! == json.null
	assert json.decode[BigHolder]('{"n":{}}', strict: true)!.n == big.zero_int
}

struct BigHolder {
	n big.Integer
}

type BigOrString = big.Integer | string

type OptionCentsOrString = ?Cents | string

struct ObjectHook {
	x int
}

fn (o ObjectHook) to_json() string {
	return '{"x":${o.x}}'
}

struct OtherObject {
	y int
}

type ObjectHookOrOther = ObjectHook | OtherObject

fn test_sumtype_variant_with_custom_encoder() {
	// A variant written by `to_json` and decoded from a scalar needs no `_type` tag.
	assert json.encode(BigOrString(big.integer_from_int(42))) == '42'
	assert json.decode[BigOrString]('42')! == BigOrString(big.integer_from_int(42))
	assert json.encode(OptionCentsOrString(?Cents(Cents{
		value: 7
	}))) == '7'
	// A variant whose `to_json` writes an object keeps its `_type` tag, so it decodes back.
	encoded := json.encode(ObjectHookOrOther(ObjectHook{
		x: 1
	}))
	assert encoded == '{"x":1,"_type":"ObjectHook"}'
	assert json.decode[ObjectHookOrOther](encoded)! == ObjectHookOrOther(ObjectHook{
		x: 1
	})
}
