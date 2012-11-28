use strictures;

package cpuPositionOffset;

use lib '../OpenGL/framework';
use OpenGL qw(
  GL_COLOR_BUFFER_BIT GL_ARRAY_BUFFER GL_FLOAT GL_FALSE GL_TRIANGLES
  GL_VERTEX_SHADER  GL_FRAGMENT_SHADER
  GL_STATIC_DRAW
  glGenBuffersARB_p
  glBindBufferARB
  glBufferDataARB_p
  glGenVertexArrays_p
  glBindVertexArray
  glViewport
  glClearColor
  glClear
  glUseProgramObjectARB
  glEnableVertexAttribArrayARB
  glVertexAttribPointerARB_c
  glDrawArrays
  glDisableVertexAttribArrayARB
  glutSwapBuffers
  glutPostRedisplay
  glUniform2fARB
  glUniform1fARB
  glGetUniformLocationARB_p
  glutMotionFunc
);
use OpenGL::Shader;

use Moo;
use Time::HiRes 'time';

use lib '../framework';

my $start = time;

with 'Framework';

has theProgram => ( is => 'rw' );

has vertexData => (
    is      => 'ro',
    default => sub {
        return OpenGL::Array->new_list(
            GL_FLOAT,    #
            -1,  1,    0.0, 1.0,
            1,  -1, 0.0, 1.0,
            -1, -1, 0.0, 1.0,
            -1,  1,    0.0, 1.0,
            1,  1, 0.0, 1.0,
            1, -1, 0.0, 1.0,
            1.0,  0.0,    0.0, 1.0,
            0.0,  1.0,    0.0, 1.0,
            0.0,  0.0,    1.0, 1.0,
            1.0,  0.0,    0.0, 1.0,
            0.0,  1.0,    0.0, 1.0,
            0.0,  0.0,    1.0, 1.0,
        );
    }
);

has $_ => ( is => 'rw' ) for qw( vertexBufferObject vao shader_view shader_time shader_mouse viewport );
has mouse => ( is => 'rw', default => sub {[1150,500]} );
use 5.010;
__PACKAGE__->new->main;
exit;

sub InitializeProgram {
    my ( $self ) = @_;
    my @shaderList;

	my $t = time;
    push @shaderList, $self->LoadShader( GL_VERTEX_SHADER,   "VertexColors.vert" );
	say "load vert:      ", time - $t, " s";
	$t = time;
    push @shaderList, $self->LoadShader( GL_FRAGMENT_SHADER, "VertexColors.frag" );
	say "load frag:      ", time - $t, " s";

	$t = time;
    $self->theProgram( $self->CreateProgram( @shaderList ) );
	say "compile both:   ", time - $t, " s";

    return;
}

sub InitializeVertexBuffer {
    my ( $self ) = @_;

    $self->vertexBufferObject( glGenBuffersARB_p( 1 ) );

=head1 insufficient documentation
    glBufferDataARB_c
=cut

    glBindBufferARB( GL_ARRAY_BUFFER, $self->vertexBufferObject );
    glBufferDataARB_p( GL_ARRAY_BUFFER, $self->vertexData, GL_STATIC_DRAW );
    glBindBufferARB( GL_ARRAY_BUFFER, 0 );

    return;
}
sub process_active_mouse_motion {
    my ( $self, $x, $y ) = @_;
	$self->mouse([$x+375,$y]);
	return;
}

sub init {
    my ( $self ) = @_;

    $self->InitializeProgram;
    $self->InitializeVertexBuffer;
	$self->shader_mouse( glGetUniformLocationARB_p( $self->theProgram, "mouse" ) );
	$self->shader_view( glGetUniformLocationARB_p( $self->theProgram, "view" ) );
	$self->shader_time( glGetUniformLocationARB_p( $self->theProgram, "time" ) );

    $self->vao( glGenVertexArrays_p( 1 ) );
    glBindVertexArray( $self->vao );
	
	glutMotionFunc( sub { $self->process_active_mouse_motion( @_ ) } );

    return;
}

sub display {
    my ( $self ) = @_;

    glClearColor( 0, 0, 0, 0 );
    glClear( GL_COLOR_BUFFER_BIT );

    glUseProgramObjectARB( $self->theProgram );

    glBindBufferARB( GL_ARRAY_BUFFER, $self->vertexBufferObject );
    glEnableVertexAttribArrayARB( 0 );
    glEnableVertexAttribArrayARB( 1 );
    glVertexAttribPointerARB_c( 0, 4, GL_FLOAT, GL_FALSE, 0, 0 );
    glVertexAttribPointerARB_c( 1, 4, GL_FLOAT, GL_FALSE, 0, 48 );

	glUniform1fARB( $self->shader_time, time - $start );
	glUniform2fARB( $self->shader_mouse, @{$self->mouse} );
	glUniform2fARB( $self->shader_view, @{$self->viewport} );

    glDrawArrays( GL_TRIANGLES, 0, 6 );

    glDisableVertexAttribArrayARB( 0 );
    glDisableVertexAttribArrayARB( 1 );
    glUseProgramObjectARB( 0 );

    glutSwapBuffers();
	glutPostRedisplay();

    return;
}

sub reshape {
    my ( $self, $w, $h ) = @_;
	$self->viewport([$w,$h]);
    glViewport( 0, 0, $w, $h );
    return;
}

sub keyboard {
    my ( $key, $x, $y ) = @_;

    glutLeaveMainLoop() if $key == 27;

    return;
}

sub defaults {
    my ( $self, $displayMode, $width, $height ) = @_;
	$$width = 1024;
	$$height = 768;
    return $displayMode;
}
