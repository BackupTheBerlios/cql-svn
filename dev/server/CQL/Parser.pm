package CQL::Parser;

use strict;
use Data::Dumper;

use vars qw(@ISA @EXPORT $VERSION);
use Exporter;
$VERSION = "1.0";
@ISA = qw(Exporter);
@EXPORT = qw(&new);

sub new
{
	my $parser = shift;
	my $statement = shift;
	my $class  = ref($parser) || $parser;
	my $self   = { @_ };

	bless($self, $class);
	
	print STDOUT Dumper($statement->columns());
	
	return $self;
}
