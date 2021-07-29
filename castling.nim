import
    types,
    bitboard

type CastlingSide* = enum
  queenside, kingside

const rookSource* = [
    queenside: [white: a1, black: a8],
    kingside: [white: h1, black: h8]]
const rookTarget* = [
    queenside: [white: d1, black: d8],
    kingside: [white: f1, black: f8]]
const kingSource* = [white: e1, black: e8]
const kingTarget* = [
    queenside: [white: c1, black: c8],
    kingside: [white: g1, black: g8]]
const checkSensitive* = [
    queenside: [white: [d1, e1], black: [d8, e8]],
    kingside: [white: [e1, f1], black: [e8, f8]]]
const blockSensitiveArea* = [
    queenside: [white: bitAt[b1] or bitAt[c1] or bitAt[d1], black: bitAt[b8] or bitAt[c8] or bitAt[d8]],
    kingside: [white: bitAt[f1] or bitAt[g1], black: bitAt[f8] or bitAt[g8]]]
