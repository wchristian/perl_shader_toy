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
  glutLeaveMainLoop
  glutWarpPointer
  glutMouseFunc
  GLUT_DOWN
  GLUT_LEFT_BUTTON
  glutSetCursor
  GLUT_CURSOR_INHERIT
  GLUT_CURSOR_NONE
);
use OpenGL::Shader;

use Moo;
use Time::HiRes 'time';
use curry;

use lib '../framework';

my $start = time;

with 'Framework';

has theProgram => ( is => 'rw' );

has vertexData => (
    is      => 'ro',
    default => sub {
        return OpenGL::Array->new_list(
            GL_FLOAT,    #
            -1,  1,   0.0, 1.0,
            1,   -1,  0.0, 1.0,
            -1,  -1,  0.0, 1.0,
            -1,  1,   0.0, 1.0,
            1,   1,   0.0, 1.0,
            1,   -1,  0.0, 1.0,
            1.0, 0.0, 0.0, 1.0,
            0.0, 1.0, 0.0, 1.0,
            0.0, 0.0, 1.0, 1.0,
            1.0, 0.0, 0.0, 1.0,
            0.0, 1.0, 0.0, 1.0,
            0.0, 0.0, 1.0, 1.0,
        );
    }
);

has $_ => ( is => 'rw' ) for qw(
  vertexBufferObject vao shader_view shader_time shader_view_pos viewport viewport_center mouse_captured mouse_pos
);
has view_pos => ( is => 'rw', default => sub { [ 1150, 500 ] } );
use 5.010;
__PACKAGE__->new->main;
exit;

sub InitializeProgram {
    my ( $self ) = @_;
    my @shaderList;

    my $t = time;
    push @shaderList, $self->LoadShader( GL_VERTEX_SHADER, "VertexColors.vert" );
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

sub process_mouse_click {
    my ( $self, $button, $state ) = @_;
    glutWarpPointer( @{ $self->viewport_center } );
    my $captured = ( $button == GLUT_LEFT_BUTTON and $state == GLUT_DOWN );
    $self->mouse_captured( $captured );
    glutSetCursor( $captured ? GLUT_CURSOR_NONE : GLUT_CURSOR_INHERIT );
    return;
}

sub process_active_mouse_motion {
    my ( $self, $x, $y ) = @_;
    $self->mouse_pos( [ $x, $y ] );
    return;
}

sub init {
    my ( $self ) = @_;

    $self->InitializeProgram;
    $self->InitializeVertexBuffer;
    $self->shader_view_pos( glGetUniformLocationARB_p( $self->theProgram, "view_pos" ) );
    $self->shader_view( glGetUniformLocationARB_p( $self->theProgram, "view" ) );
    $self->shader_time( glGetUniformLocationARB_p( $self->theProgram, "time" ) );

    $self->vao( glGenVertexArrays_p( 1 ) );
    glBindVertexArray( $self->vao );

    glutMotionFunc( $self->curry::process_active_mouse_motion );
    glutMouseFunc( $self->curry::process_mouse_click );

    return;
}

sub display {
    my ( $self ) = @_;

    if ( $self->mouse_captured ) {
        my $center = $self->viewport_center;
        glutWarpPointer( @{$center} );
        my $mouse_pos = $self->mouse_pos;
        my $view_pos  = $self->view_pos;
        $view_pos->[$_] -= $center->[$_] - $mouse_pos->[$_] for 0, 1;
    }

    glClearColor( 0, 0, 0, 0 );
    glClear( GL_COLOR_BUFFER_BIT );

    glUseProgramObjectARB( $self->theProgram );

    glBindBufferARB( GL_ARRAY_BUFFER, $self->vertexBufferObject );
    glEnableVertexAttribArrayARB( 0 );
    glEnableVertexAttribArrayARB( 1 );
    glVertexAttribPointerARB_c( 0, 4, GL_FLOAT, GL_FALSE, 0, 0 );
    glVertexAttribPointerARB_c( 1, 4, GL_FLOAT, GL_FALSE, 0, 48 );

    glUniform1fARB( $self->shader_time, time - $start );
    glUniform2fARB( $self->shader_view_pos, @{ $self->view_pos } );
    glUniform2fARB( $self->shader_view,     @{ $self->viewport } );

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
    $self->viewport( [ $w, $h ] );
    $self->viewport_center( [ map int( $_ / 2 ), $w, $h ] );
    glViewport( 0, 0, $w, $h );
    return;
}

sub keyboard {
    my ( $self, $key, $x, $y ) = @_;

    glutSetCursor( GLUT_CURSOR_INHERIT ), glutLeaveMainLoop() if $key == 27;

    return;
}

sub defaults {
    my ( $self, $displayMode, $width, $height ) = @_;
    $$width  = 1024;
    $$height = 768;
    return $displayMode;
}
