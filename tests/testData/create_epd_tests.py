#!/usr/bin/env python3
"""
PGN to FEN Extractor using python-chess

This script processes all *.pgn files in the current directory and extracts
all positions as FEN strings, writing them to corresponding *.epd files.
Useful for validating custom PGN parsers by comparing the extracted positions.

Usage:
    python pgn_fen_extractor.py [--no-starting-position]
"""

import chess
import chess.pgn
import sys
import argparse
from pathlib import Path
import glob


def extract_fens_from_pgn(pgn_file_path, output_file_path, include_starting_position=True):
    """
    Extract all FEN positions from a PGN file and write them to a text file.

    Args:
        pgn_file_path (str): Path to the input PGN file
        output_file_path (str): Path to the output FEN file
        include_starting_position (bool): Whether to include the starting position FEN
    """

    try:
        with open(pgn_file_path, 'r', encoding='utf-8') as pgn_file:
            with open(output_file_path, 'w', encoding='utf-8') as fen_file:
                game_count = 0
                total_positions = 0

                while True:
                    # Load the next game from the PGN file
                    print(f"Will processe game {game_count+1}...")
                    game = chess.pgn.read_game(pgn_file)
                    if game is None:
                        break

                    game_count += 1
                    print(f"Processing game {game_count}...")

                    # Get the board from the game
                    board = game.board()

                    # Write starting position if requested
                    if include_starting_position:
                        fen_file.write(board.fen() + '\n')
                        total_positions += 1

                    # Iterate through all moves in the game
                    for move in game.mainline_moves():
                        board.push(move)
                        fen_file.write(board.fen() + '\n')
                        total_positions += 1

                print(f"Completed processing {game_count} games.")
                print(f"Total positions extracted: {total_positions}")
                print(f"FEN positions written to: {output_file_path}")

    except FileNotFoundError:
        print(f"Error: Could not find PGN file '{pgn_file_path}'")
        sys.exit(1)
    except IOError as e:
        print(f"Error reading/writing files: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Extract FEN positions from all *.pgn files in current directory",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python pgn_fen_extractor.py
    python pgn_fen_extractor.py --no-starting-position
        """
    )

    parser.add_argument(
        '--no-starting-position',
        action='store_true',
        help='Skip the starting position (only include positions after moves)'
    )

    args = parser.parse_args()

    # Find all PGN files in current directory
    pgn_files = glob.glob("*.pgn")

    if not pgn_files:
        print("No *.pgn files found in the current directory.")
        sys.exit(1)

    print(f"Found {len(pgn_files)} PGN file(s): {', '.join(pgn_files)}")

    # Process each PGN file
    include_starting = not args.no_starting_position

    for pgn_file in pgn_files:
        # Generate corresponding EPD filename
        epd_file = Path(pgn_file).with_suffix('.epd')

        print(f"\nProcessing: {pgn_file} -> {epd_file}")
        extract_fens_from_pgn(pgn_file, str(epd_file), include_starting)


if __name__ == "__main__":
    main()
